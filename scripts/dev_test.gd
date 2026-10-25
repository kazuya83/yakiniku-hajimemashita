extends Node
## 開発用：起動引数 --test で、一連の操作を自動で試す

var t := 0.0
var step := 0
var g: Grill
var c: Customer


func _ready() -> void:
	Engine.time_scale = 8.0


func _ok(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)


func _process(dt: float) -> void:
	t += dt
	var m = Game.main
	var p: Player = m.player
	match step:
		0:
			g = m.grills[1]
			var fr: Fridge
			for n in m.get_node("Shop").get_children():
				if n is Fridge:
					fr = n
			fr.selected = 1
			var money0 := Game.money
			fr.use(p)
			_ok(p.held is Plate and p.held.meats.size() == 4, "冷蔵庫から皿を出す")
			_ok(Game.money < money0, "仕入れ代が引かれる")
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
				step = 4
				t = 0
				set_meta("money0", money0)
			elif t > 200.0:
				_ok(false, "お客さんが来ない")
				get_tree().quit()
		4:
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
				var sink: Sink
				var cb: CharcoalBox
				for n in m.get_node("Shop").get_children():
					if n is Sink:
						sink = n
					if n is CharcoalBox:
						cb = n
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
				step = 5
				t = 0
			elif t > 120:
				_ok(false, "お客さんが帰らない state=" + c.state)
				get_tree().quit()
		5:
			m.day_time = m.day_length
			step = 6
		6:
			if m.phase == "summary":
				_ok(true, "閉店して日報が出る")
				m.next_day()
				_ok(Game.day == 2 and m.phase == "prep", "次の日へ")
				get_tree().quit()
			elif t > 400:
				_ok(false, "閉店しない phase=" + m.phase)
				get_tree().quit()
