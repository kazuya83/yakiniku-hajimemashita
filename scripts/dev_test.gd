extends Node
## 開発用：起動引数 --test で、一連の操作を自動で試す

var t := 0.0
var step := 0
var g: Grill
var c: Customer


func _ready() -> void:
	Game.toast.connect(func(t): print("  [toast] ", t))
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.hud._begin.call_deferred()
	Engine.time_scale = 8.0
	if Game.has_meta("savetest"):
		step = 90


func _deliver(pt: TableParty, c: String, fr: Fridge, p: Player) -> void:
	if MeatData.is_drink(c):
		var d := Drink.new()
		Game.main.items_root.add_child(d)
		d.drink = c
		d.level = 0.7
		d.foam = 0.25 if c == "beer" else 0.0
		p.pick(d)
	else:
		fr.take(c, p)
	pt.table.primary(p, pt.table.global_position, Vector3.UP)
	if p.held:
		print("  渡せなかった: ", c, " held=", p.held.display_name(), " items=", pt.table.items.size())
		p.held.detach()
		p.held = null


func _find(cls) -> Node:
	for n in Game.main.get_node("Shop").find_children("*", "", true, false):
		if is_instance_of(n, cls):
			return n
	return null


func _put(n: Node3D, pos: Vector3, yaw: float) -> bool:
	var b: BuildMode = Game.main.build
	n.position = pos
	n.rotation.y = yaw
	b._valid = b.fits(n, pos, yaw)
	return b.place()


func tb_has_party(pt) -> bool:
	return pt.table.party == pt


func _ok(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)


func _process(dt: float) -> void:
	t += dt
	var m = Game.main
	var p: Player = m.player
	match step:
		0:
			_ok(p.global_position.distance_to(OutsideBuilder.HOME_POS) < 0.5, "朝は自宅の前から")
			_ok(Game.money >= 300000, "資金 ¥300,000 で店長としてスタート")
			m.clock_in()
			_ok(m.clocked_in, "タイムカードで出社")
			g = m.grills[1]
			var fr: Fridge = _find(Fridge)
			fr.use(p)
			_ok(fr.is_open, "冷蔵庫の扉が開く")
			fr.take("karubi", p)
			_ok(p.held is Plate and p.held.meats.size() == 4, "冷蔵庫から皿を出す")
			_ok(Game.stock_count("karubi") == 12, "在庫が減る")
			# 皿を作業台に置く
			p.place_at(g.global_position + Vector3(0.45, 0, 0.05))
			var pl: Plate = m.items_root.get_children().filter(func(x): return x is Plate)[0]
			_ok(p.held == null and pl.meats.size() == 4, "皿を置く")
			for i in 2:
				var me: Meat = pl.meats[0]
				me.primary(p, me.global_position, Vector3.UP)
				_ok(p.held == me, "肉をトングでつかむ")
				g.primary(p, g.to_global(Vector3(-0.05 + i * 0.1, 0.2, 0)), Vector3.UP)
				_ok(p.held == null and me.container == g, "網にのせる")
			m.open_shop()
			step = 1
			t = 0
		1:
			m._spawn_t = 99999.0
			if t > 30.0:
				for me in g.meats:
					me.secondary(p)
				print("  30秒: ", g.meats.map(func(x): return "%s sear=%s core=%.2f fat=%.2f" % [x.state_word(), str(x.sear), x.core, x.fat]))
				print("  網の汚れ %.2f 火力 %.2f 炭 %.2f" % [g.grate.dirt, g.heat, g.coal])
				step = 2
				t = 0
		2:
			if t > 30.0:
				print("  60秒: ", g.meats.map(func(x): return "%s sear=%s core=%.2f score=%.2f" % [x.state_word(), str(x.sear), x.core, x.score()]))
				# お客さんを待つ
				step = 3
				t = 0
		3:
			m._spawn_t = 99999.0
			if m._customers.is_empty():
				var cs := Customer.new().setup(m.seats[0], "harami", 2, m.door_pos)
				m.add_child(cs)
				m.seats[0].customer = cs
				m._customers.append(cs)
			for s in m.seats:
				if s.customer and s.customer.is_seated():
					c = s.customer
			if c:
				print("  お客さん: ", c.order_text())
				var target_cut := c.cut
				# 注文の肉を作って焼けた状態にして出す
				var money0 := Game.money
				for i in c.count:
					var me := Meat.new().setup(target_cut)
					m.items_root.add_child(me)
					me.sear = [0.7, 0.75]
					me.core = (me.data.ideal.x + me.data.ideal.y) / 2
					p.pick(me)
					c.seat.primary(p, c.seat.global_position, Vector3.UP)
				_ok(c.served == c.count, "肉を出す")
				if c.drink != "":
					var d := Drink.new()
					m.items_root.add_child(d)
					d.drink = c.drink
					d.level = 0.7
					d.foam = 0.25 if c.drink == "beer" else 0.0
					p.pick(d)
					c.seat.primary(p, c.seat.global_position, Vector3.UP)
					_ok(c.drink_served, "飲み物を出す")
				step = 4
				t = 0
				set_meta("money0", money0)
			elif t > 200.0:
				_ok(false, "お客さんが来ない")
				get_tree().quit()
		4:
			if is_instance_valid(c) and c.state == "at_register":
				var reg: Register = m.register()
				_ok(reg.waiting() and reg.front() == c, "食べ終わったお客さんがレジに並ぶ（%s）" % Game.yen(c.bill_total()))
				p.global_position = reg.global_position + Vector3(0, 0.05, -0.8)
				reg.use(p)
			if not is_instance_valid(c) or c.state == "leave":
				_ok(Game.money > get_meta("money0"), "お会計される: " + Game.yen(Game.money - get_meta("money0")))
				_ok(Game.reviews.size() > 0, "評価がつく: " + str(Game.reviews))
				# 網を外して洗う
				for me in g.meats.duplicate():
					me.primary(p, me.global_position, Vector3.UP)
					p.place_at(g.global_position + Vector3(0.45, 0, -0.1))
				g.grate.add_dirt(0.8)
				g.primary(p, g.global_position, Vector3.UP)
				_ok(p.held is Grate and g.grate == null, "網を外す")
				var sink: Sink = _find(Sink)
				var cb: CharcoalBox = _find(CharcoalBox)
				var coal0 := g.coal
				var gr: Grate = p.held
				sink.primary(p, sink.global_position, Vector3.UP)
				for i in 200:
					sink.hold_use(p, 0.05)
				_ok(gr.dirt == 0.0, "網を洗う")
				cb.use(p)
				g.primary(p, g.global_position, Vector3.UP)
				_ok(g.coal > coal0, "炭を足す")
				sink.primary(p, sink.global_position, Vector3.UP)
				g.primary(p, g.global_position, Vector3.UP)
				_ok(g.grate == gr, "網を戻す")
				step = 10
				t = 0
			elif t > 120:
				_ok(false, "お客さんが帰らない state=" + c.state)
				get_tree().quit()
		10:
			for c in MeatData.ORDER:
				Game.add_stock(c, 40)
			var tb: DiningTable = m.tables[0]
			var pt := TableParty.new().setup(tb, 2, m.door_pos)
			pt.ctype = "normal"
			m.add_child(pt)
			tb.party = pt
			m._parties.append(pt)
			set_meta("pt", pt)
			step = 11
			t = 0
		11:
			var pt: TableParty = get_meta("pt")
			if pt.state == "call_order":
				_ok(true, "テーブル客が座って注文を呼ぶ")
				pt.on_use(p)
				_ok(Game.hud.ticket_open(), "伝票が開く: " + pt.order_text())
				Game.hud._ticket_add(pt.order.keys()[0], 1)
				Game.hud._close_ticket()
				_ok(not pt.ticket.is_empty(), "伝票に書ける: " + pt.ticket_text())
				var fr: Fridge = _find(Fridge)
				for c in pt.order:
					for k in pt.order[c]:
						_deliver(pt, c, fr, p)
				_ok(pt.state == "eating", "皿を出すと焼き始める")
				set_meta("money1", Game.money)
				step = 12
				t = 0
			elif t > 120:
				_ok(false, "テーブル客が注文しない state=" + pt.state)
				get_tree().quit()
		12:
			if not is_instance_valid(get_meta("pt")):
				_ok(false, "テーブル客が途中で帰った")
				get_tree().quit()
				return
			var pt: TableParty = get_meta("pt")
			if is_instance_valid(pt) and pt.state == "call_order":
				pt.on_use(p)
				Game.hud._close_ticket()
				for c in pt.order:
					var need: int = pt.order[c] - pt.delivered.get(c, 0)
					for k in need:
						var fr: Fridge = _find(Fridge)
						_deliver(pt, c, fr, p)
				print("  追加注文: ", pt.order_text())
			if is_instance_valid(pt) and pt.need == "grate":
				print("  網交換の依頼")
				pt.table.grill.grate.dirt = 0.0
			if is_instance_valid(pt) and pt.need == "fire":
				print("  炭を足す依頼")
				pt.table.grill.coal = 1.0
			if is_instance_valid(pt) and pt.state == "at_register":
				print("  食べた枚数 ", pt.eaten, " 平均 ", pt._food_score())
				var reg: Register = m.register()
				_ok(reg.front() == pt and not tb_has_party(pt), "テーブル客が席を立ってレジに並ぶ")
				reg.use(p)
				_ok(Game.money > get_meta("money1"), "テーブルのお会計: " + Game.yen(Game.money - get_meta("money1")))
				step = 13
				t = 0
			elif t > 900:
				_ok(false, "テーブル客が食べ終わらない state=" + (pt.state if is_instance_valid(pt) else "freed"))
				get_tree().quit()
		13:
			var tb: DiningTable = m.tables[0]
			if t > 30:
				_ok(not tb.is_clean(), "帰ったあと皿が残る")
				var sink: Sink = _find(Sink)
				for pl in tb.items.duplicate():
					pl.primary(p, pl.global_position, Vector3.UP)
					if p.held is Plate and not p.held.meats.is_empty():
						p.held.meats.clear()
					sink.primary(p, sink.global_position, Vector3.UP)
				_ok(not tb.is_clean() and tb.dirty, "皿とジョッキを下げる (洗い物 皿%d ジョッキ%d)" % [Game.dirty_plates, Game.dirty_jugs])
				for i in 60:
					tb.hold_use(p, 0.05)
				_ok(tb.is_clean(), "テーブルを拭く")
				var cp := Game.clean_plates
				for i in 200:
					sink.hold_use(p, 0.05)
				_ok(Game.clean_plates > cp and Game.dirty_plates == 0, "皿洗い")
				step = 20
				t = 0
		20:
			# ビールを注ぐ
			var tap: DrinkTap
			for n in Game.main.get_node("Shop").find_children("*", "DrinkTap", true, false):
				if n.drink == "beer":
					tap = n
			var jr: JugRack = _find(JugRack)
			jr.primary(p, jr.global_position, Vector3.UP)
			_ok(p.held is Drink, "ジョッキを取る")
			tap.tilt = 35.0
			for i in 70:
				tap.hold_use(p, 0.05)
			tap.tilt = 5.0
			for i in 25:
				tap.hold_use(p, 0.05)
			var d: Drink = p.held
			print("  ビール 液%.2f 泡%.2f 点%.2f" % [d.level, d.foam, d.score()])
			_ok(d.score() > 0.6, "ビールをうまく注げる")
			p.place_at(Vector3(2.0, 0.95, -1.2))
			# 発注して翌日届く
			Game.hud.open_purchase()
			Game.hud._buy_add("karubi", 2)
			var money0 := Game.money
			Game.hud._buy_confirm()
			_ok(Game.money < money0 and Game.orders.get("karubi", 0) == 2, "発注する")
			step = 5
			t = 0
		5:
			m.day_time = m.day_length
			for s in m.seats:
				if s.customer:
					s.customer.patience = 0.0
			step = 6
		6:
			if m.phase == "summary":
				_ok(true, "閉店して日報が出る")
				var st := Game.stock_count("karubi")
				m.next_day()
				_ok(Game.day == 2 and m.phase == "prep", "次の日へ")
				m.clock_in()
				var boxes: Array = m.items_root.get_children().filter(func(x): return x is SupplyBox)
				_ok(boxes.size() == 2, "段ボールが届く")
				var fr: Fridge = _find(Fridge)
				for b in boxes:
					p.pick(b)
					fr.primary(p, fr.global_position, Vector3.UP)
				_ok(Game.stock_count("karubi") == st + 40, "冷蔵庫にしまう")
				step = 30
				t = 0
			elif t > 400:
				_ok(false, "閉店しない phase=" + m.phase)
				get_tree().quit()
		30:
			# お店づくり
			Game.money += 300000
			var b: BuildMode = m.build
			b.toggle()
			_ok(b.active, "お店づくりモードに入る")
			var t0: DiningTable = m.tables[0]
			b.pick(t0)
			_ok(not _put(t0, Vector3(-2.0, 0, -0.5), 0.0), "カウンターには置けない")
			_ok(not _put(t0, Vector3(0.4, 0, 2.6), 0.0), "ほかのテーブルには重ねられない")
			_ok(_put(t0, Vector3(-3.5, 0, 2.5), PI / 2) and b.carrying == null, "テーブルを回して置く")
			_ok(absf(t0.chairs[0].x - t0.global_position.x) > 0.5, "椅子の位置もいっしょに回る")
			var fr: Fridge = _find(Fridge)
			b.pick(fr)
			_ok(_put(fr, Vector3(-5.25, 0, -2.5), PI / 2), "冷蔵庫を動かす")
			var money0 := Game.money
			b.expand()
			_ok(b.expanded and m.room_max_x > 7.0 and Game.money == money0 - BuildMode.EXPAND_PRICE, "隣の区画を買って広げる")
			b.buy("table")
			var nt: DiningTable = b.carrying
			_ok(nt != null and m.tables.size() == 3, "テーブルを買う")
			_ok(_put(nt, Vector3(8.0, 0, 1.5), 0.0), "広げた所にテーブルを置く")
			b.buy("plant")
			var pl: Node3D = b.carrying
			_ok(_put(pl, Vector3(-5.5, 0, 4.0), 0.0), "観葉植物を置く")
			b.set_wall("墨色")
			b.set_floor("木の床")
			_ok(b.wall_name == "墨色" and b.floor_name == "木の床", "壁紙と床を変える")
			b.close_shop()
			b.toggle()
			_ok(not b.active, "お店づくりを終える")
			step = 31
			t = 0
		31:
			if t > 2.0:
				var map := m.get_world_3d().navigation_map
				var ok := true
				for tb in m.tables:
					for i in tb.chairs.size():
						var a: Vector3 = tb.chair_approach(i)
						var pts := NavigationServer3D.map_get_path(map, m.door_pos, a, true)
						if pts.is_empty() or Vector2(pts[-1].x, pts[-1].z).distance_to(Vector2(a.x, a.z)) > 0.6:
							ok = false
							print("  届かない: テーブル", tb.index, " 椅子", i, " ", a, " → ", pts[-1] if not pts.is_empty() else "なし")
				_ok(ok, "入口からすべての椅子まで歩ける")
				for s in m.seats:
					var pts := NavigationServer3D.map_get_path(map, m.door_pos, s.stool_pos + Vector3(0, 0, 0.35), true)
					ok = ok and not pts.is_empty() and Vector2(pts[-1].x, pts[-1].z).distance_to(Vector2(s.stool_pos.x, s.stool_pos.z + 0.35)) < 0.6
				_ok(ok, "入口からカウンター席まで歩ける")
				m.open_shop()
				m._spawn_t = 99999.0
				var tb: DiningTable = m.tables[2]
				var pt := TableParty.new().setup(tb, 4, m.door_pos)
				m.add_child(pt)
				tb.party = pt
				m._parties.append(pt)
				set_meta("pt2", pt)
				step = 32
				t = 0
		32:
			m._spawn_t = 99999.0
			var pt: TableParty = get_meta("pt2")
			if pt.state == "call_order":
				_ok(true, "広げた所のテーブルにお客さんが座る")
				step = 40
				t = 0
			elif t > 150:
				_ok(false, "新しいテーブルにたどり着かない state=" + pt.state)
				get_tree().quit()
		40:
			# 第5段階：店の格と成長要素
			m._spawn_t = 99999.0
			Game.fame = 0.0
			_ok(Game.level() == 1, "店の格 Lv1 から")
			Game.add_fame(5.0)
			Game.fame = 250.0
			_ok(Game.level() == 4, "星がたまると店の格が上がる: " + Game.level_text())
			Game.money += 500000
			var b: BuildMode = m.build
			for k in ["extend", "touch", "selfcut", "premium"]:
				_ok(b.buy_upgrade(k) and Game.has(k), "成長要素を買う: " + Game.UPGRADES[k].name)
			_ok(b.buy_upgrade("dishwasher") and b.carrying is Dishwasher, "食洗機を買う")
			var dw: Dishwasher = b.carrying
			b.carrying = null
			dw.position = Vector3(-2.0, 0, -3.3)
			_ok(MeatData.menu().size() == 6 and m.menu_label.text.contains("特上カルビ"), "高級部位がメニューに出る")
			m.hire("clean")
			_ok(m.staff.size() == 1 and m.wages() == 7000, "片づけ担当のアルバイトを雇う")
			# 食洗機
			Game.dirty_plates = 5
			Game.dirty_jugs = 3
			var cp := Game.clean_plates
			_ok(dw.start() and Game.dirty_plates == 0, "食洗機に入れて回す")
			set_meta("dw", dw)
			set_meta("cp", cp)
			# 自家カット
			Game.blocks["karubi"] = 1
			var cbd: CuttingBoard = _find(CuttingBoard)
			cbd.get_hint(p)
			var st := Game.stock_count("karubi")
			for i in 200:
				cbd.hold_use(p, 0.05)
			_ok(Game.stock_count("karubi") == st + Game.BLOCK_SLICES and Game.blocks["karubi"] == 0, "塊肉を切って在庫が増える")
			# タッチパネル注文
			var tb: DiningTable = m.tables[1]
			_ok(tb.has_node("Touch"), "テーブルにタッチパネルがつく")
			for c in MeatData.ORDER:
				Game.add_stock(c, 40)
			var pt := TableParty.new().setup(tb, 2, m.door_pos)
			m.add_child(pt)
			tb.party = pt
			m._parties.append(pt)
			set_meta("pt3", pt)
			step = 41
			t = 0
		41:
			m._spawn_t = 99999.0
			var pt: TableParty = get_meta("pt3")
			if pt.state == "wait_food":
				_ok(not pt.ticket.is_empty(), "タッチパネルで注文が自動で入る: " + pt.ticket_text())
				var dw: Dishwasher = get_meta("dw")
				_ok(dw.running > 0.0, "食洗機が動いている")
				step = 42
				t = 0
			elif t > 120:
				_ok(false, "タッチパネル注文が入らない state=" + pt.state)
				get_tree().quit()
		42:
			m._spawn_t = 99999.0
			if t > 30.0:
				_ok(Game.clean_plates >= get_meta("cp") + 5, "食洗機で皿がきれいになる")
				# アルバイトの片づけ
				var tb: DiningTable = m.tables[0]
				var pl := Plate.new()
				m.items_root.add_child(pl)
				tb.put_plate(pl)
				tb.set_dirty()
				set_meta("tb0", tb)
				step = 43
				t = 0
		43:
			m._spawn_t = 99999.0
			var tb: DiningTable = get_meta("tb0")
			if tb.is_clean():
				_ok(true, "アルバイトがテーブルを片づけて拭く")
				# 客タイプ
				var types := {}
				for i in 400:
					types[Game.pick_type(true)] = true
				_ok(types.size() == 5, "客タイプ（ふつう・常連・団体・クレーマー・食通）が出る: " + str(types.keys()))
				_ok(Game.type_stars("gourmet", 4.0, 0.9) == 5.0 and Game.type_stars("complainer", 4.0, 0.7) == 3.0, "食通は上手だと星+1、クレーマーは厳しい")
				m.open_shop()
				_ok(m.day_length == 700.0, "営業時間が延びる")
				# 焼き担当とホール担当
				Game.unlocked.erase("touch")
				m.hire("cook")
				m.hire("hall")
				for c in MeatData.ORDER:
					Game.add_stock(c, 40)
				Game.clean_plates += 20
				var s: Seat = m.seats[2]
				if s.customer:
					s.customer.queue_free()
				var cs := Customer.new().setup(s, "karubi", 2, m.door_pos)
				m.add_child(cs)
				s.customer = cs
				m._customers.append(cs)
				set_meta("cs", cs)
				var tb2: DiningTable = m.tables[1]
				tb2.clear_all()
				tb2.finish_wipe()
				var pt := TableParty.new().setup(tb2, 2, m.door_pos)
				pt.ctype = "normal"
				m.add_child(pt)
				tb2.party = pt
				m._parties.append(pt)
				set_meta("pt4", pt)
				set_meta("m4", Game.money)
				step = 44
				t = 0
			elif t > 120:
				_ok(false, "アルバイトが片づけない job=" + m.staff[0].job)
				get_tree().quit()
		44:
			m._spawn_t = 99999.0
			var cs = get_meta("cs")
			if not get_meta("cdone", false) and (not is_instance_valid(cs) or cs.state == "leave"):
				_ok(is_instance_valid(cs) and cs.by_staff, "焼き担当がカウンターのお客さんに焼いて出す")
				set_meta("cdone", true)
			var pt = get_meta("pt4")
			if not is_instance_valid(pt) or pt.state == "leave":
				_ok(Game.money > get_meta("m4") and is_instance_valid(pt) and pt.eaten > 0, "ホール担当が注文・配膳・お会計までやる（食べた %d 枚）" % (pt.eaten if is_instance_valid(pt) else -1))
				var w: int = m.wages()
				m.day_time = m.day_length
				set_meta("w", w)
				step = 45
				t = 0
			elif t > 900:
				_ok(false, "ホール担当でテーブルが回らない state=%s order=%s delivered=%s" % [pt.state, pt.order, pt.delivered])
				get_tree().quit()
		90:
			if t < 0.5:
				return
			var exp: Dictionary = Game.get_meta("savetest")
			var ok := SaveData.load_into(m)
			_ok(ok and Game.money == exp.money and Game.day == exp.day, "セーブを読み込む（所持金・日付）money=%d day=%d" % [Game.money, Game.day])
			_ok(m.staff.size() == exp.staff, "アルバイトも続きから（%d人）" % m.staff.size())
			var tx := -999.0
			for tb in m.tables:
				if is_instance_valid(tb) and not tb.is_queued_for_deletion():
					tx = tb.position.x if absf(tb.position.x - exp.tx) < 0.01 else tx
			_ok(m.tables.size() == exp.tables and absf(tx - exp.tx) < 0.01, "テーブルの配置も続きから")
			_ok(is_equal_approx(Game.fame, exp.fame), "店の格のポイントも続きから")
			get_tree().quit()
		45:
			m._spawn_t = 99999.0
			if m.phase == "summary":
				_ok(get_meta("w") == 24000, "閉店後にアルバイト代をはらう")
				m.next_day()
				_ok(not m.clocked_in and m.staff.size() == 3, "次の日は家から。アルバイトはお店にいる")
				_ok(m.fire("cook") and m.staff.size() == 2, "アルバイトに辞めてもらう")
				# セーブ → 読み込みの確認（シーンを読み直して続きから）
				var tb0: DiningTable = m.tables[0]
				tb0.position.x += 0.25
				Game.money += 1234
				SaveData.save(m, false)
				Game.set_meta("savetest", {"money": Game.money, "day": Game.day, "staff": m.staff.size(),
					"tables": m.tables.size(), "tx": tb0.position.x, "fame": Game.fame})
				Game.money = 1
				Game.day = 99
				get_tree().reload_current_scene()
			elif t > 400:
				_ok(false, "閉店しない phase=" + m.phase)
				get_tree().quit()
