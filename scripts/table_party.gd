class_name TableParty
extends Node3D
## テーブル席のお客さんのグループ。注文→自分たちで焼いて食べる→追加注文→お会計

var table: DiningTable
var members: Array[Person] = []
var state := "walk_in"
var order := {}       # 部位 → 注文された皿数（本当の注文）
var delivered := {}   # 部位 → 届いた皿数
var ticket := {}      # 部位 → 伝票に書いた皿数
var patience := 90.0
var need := ""        # "grate" / "fire"
var scores: Array[float] = []
var eaten := 0
var service := 1.0
var rounds := 0
var _bubble: Label3D
var _say_t := 0.0
var _said := ""
var _t := 0.0
var _ai_t := 2.0
var _flip_at := {}    # 肉 → ひっくり返す焼き色
var _flipped_once := {}
var _plates_given: Array[Plate] = []


func setup(t: DiningTable, n: int, door: Vector3) -> TableParty:
	table = t
	for i in n:
		var p := Person.new()
		add_child(p)
		p.position = door + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.2, 0.2))
		p.path = Game.main.nav_path(p.position, t.chair_approach(i))
		p.path.append(t.chairs[i])
		p.speed = randf_range(1.1, 1.4)
		members.append(p)
	_bubble = Build.label(self, "", Vector3.ZERO, 44)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.outline_size = 12
	_bubble.outline_modulate = Color(0, 0, 0, 0.8)
	return self


func say(t: String) -> void:
	_said = t
	_say_t = 4.0


func status_text() -> String:
	match state:
		"walk_in":
			return "ご案内中"
		"seated":
			return "メニューを見ている"
		"call_order":
			return "注文を呼んでいる"
		"wait_food", "eating":
			return "%s（届いた %d/%d）" % [order_text(), _sum(delivered), _sum(order)]
		"call_bill":
			return "お会計を呼んでいる"
	return "帰るところ"


func need_text() -> String:
	return "網を替えてほしい" if need == "grate" else "火が弱い"


func order_text() -> String:
	var parts: Array[String] = []
	for c in MeatData.ORDER + MeatData.DRINK_ORDER:
		if order.get(c, 0) > 0:
			parts.append("%s%d%s" % [MeatData.item_name(c), order[c], "杯" if MeatData.is_drink(c) else "皿"])
	return "、".join(parts)


func ticket_text() -> String:
	var parts: Array[String] = []
	for c in MeatData.ORDER + MeatData.DRINK_ORDER:
		if ticket.get(c, 0) > 0:
			parts.append("%s%d" % [MeatData.item_name(c), ticket[c]])
	return "・".join(parts) if not parts.is_empty() else "（未記入）"


func _sum(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += d[k]
	return s


func _process(dt: float) -> void:
	_t += dt
	_say_t -= dt
	match state:
		"walk_in":
			var done := true
			for i in members.size():
				var m := members[i]
				if not m.seated:
					if m.walk(dt):
						m.sit(table.chair_yaw[i], -0.38)
					else:
						done = false
			if done:
				state = "seated"
				_t = 0.0
		"seated":
			if _t > randf_range(5.0, 9.0):
				_call("call_order", "すみませーん！注文お願いします")
		"call_order", "call_bill":
			patience -= dt
			if patience <= 0.0:
				say("もう帰ります！")
				_leave(true)
		"wait_food", "eating":
			_eat_loop(dt)
		"leave":
			var done := true
			for m in members:
				if not m.walk(dt):
					done = false
			if done:
				Game.main.party_left(self)
				queue_free()
	_update_bubble()


func _call(st: String, text: String) -> void:
	state = st
	patience = 70.0
	members[0].raise_hand(true)
	say(text)


func on_use(_p: Player) -> void:
	match state:
		"call_order":
			members[0].raise_hand(false)
			_make_order()
			say("%sお願いします！" % order_text())
			_say_t = 9.0
			state = "wait_food"
			patience = 200.0
			Game.hud.open_ticket(self)
		"call_bill":
			_pay()


func _make_order() -> void:
	var n := maxi(1, members.size() - 1 + randi_range(0, 1)) if rounds == 0 else randi_range(1, 2)
	for i in n:
		var c: String = MeatData.ORDER.pick_random()
		order[c] = order.get(c, 0) + 1
	for i in members.size():
		if randf() < (0.7 if rounds == 0 else 0.3):
			var d: String = ["beer", "beer", "beer", "highball", "oolong"].pick_random()
			order[d] = order.get(d, 0) + 1
	rounds += 1


func wants(it: Item) -> bool:
	if it is Drink:
		return it.drink != "" and it.level > 0.2 and order.get(it.drink, 0) > delivered.get(it.drink, 0)
	var pl: Plate = it
	if pl.meats.is_empty():
		return false
	var c := pl.meats[0].cut
	for m in pl.meats:
		if m.cut != c:
			return false
	return order.get(c, 0) > delivered.get(c, 0)


var _drinks := {}   # ジョッキ → 飲み終わるまでの秒数


func on_item(it: Item) -> void:
	if it is Drink:
		delivered[it.drink] = delivered.get(it.drink, 0) + 1
		var s: float = it.score()
		scores.append(s)
		_drinks[it] = randf_range(25.0, 45.0)
		if it.drink == "beer":
			say("かんぱーい！" if s > 0.75 else "泡のバランスがちょっと…")
		else:
			say("ありがとうございます！")
	else:
		var c: String = it.meats[0].cut
		delivered[c] = delivered.get(c, 0) + 1
		_plates_given.append(it)
		say("ありがとうございます！")
	state = "eating"
	if patience < 60.0:
		service -= 0.15
	patience = maxf(patience, 120.0)


func _eat_loop(dt: float) -> void:
	var g := table.grill
	for d in _drinks.keys():
		if not is_instance_valid(d) or d.container != table:
			_drinks.erase(d)
			continue
		_drinks[d] -= dt
		var full: float = d.level + d.foam
		if full > 0.0:
			d.level = maxf(d.level - dt * 0.02, 0.0)
			d.foam = maxf(d.foam - dt * 0.01, 0.0)
			d.refresh()
		if _drinks[d] <= 0.0:
			d.drink = ""
			d.level = 0.0
			d.foam = 0.0
			d.empty_used = true
			d.refresh()
			_drinks.erase(d)
	# 待ち時間（焼く物がないのに注文が届いていない）
	var raw_left := 0
	for pl in _plates_given:
		if is_instance_valid(pl) and pl.container == table:
			raw_left += pl.meats.size()
	var my_on_grill: Array[Meat] = []
	for m in g.meats:
		if _flip_at.has(m):
			my_on_grill.append(m)
	if raw_left == 0 and my_on_grill.is_empty() and _sum(delivered) < _sum(order):
		patience -= dt
		if patience <= 0.0:
			say("全然来ないので帰ります")
			_leave(true)
			return
	# 網や火の困りごと
	if need == "grate" and g.grate and g.grate.dirt < 0.3:
		need = ""
		members[0].raise_hand(false)
		say("網ありがとう！")
		service += 0.1
	elif need == "fire" and g.heat > 0.5:
		need = ""
		members[0].raise_hand(false)
		say("火が戻った！")
	_ai_t -= dt
	if _ai_t > 0.0:
		return
	_ai_t = randf_range(1.0, 2.2)
	# 焼けた肉を食べる・ひっくり返す
	for m in my_on_grill:
		var down := 0 if m.flipped else 1
		if not _flipped_once.get(m, false):
			if m.sear[down] >= _flip_at[m]:
				m.flip(g.is_sticky())
				_flipped_once[m] = true
				return
		elif m.sear[down] >= _flip_at[m] * randf_range(0.8, 1.0) and m.core >= m.data.ideal.x * randf_range(0.85, 1.05):
			scores.append(m.score())
			eaten += 1
			_flip_at.erase(m)
			_flipped_once.erase(m)
			m.detach()
			m.queue_free()
			return
	if g.grate == null:
		return
	if g.is_sticky() and need == "":
		need = "grate"
		members[0].raise_hand(true)
		say("すみません、網を替えてください！")
		return
	if g.heat < 0.3 and g.coal < 0.25 and need == "":
		need = "fire"
		members[0].raise_hand(true)
		say("すみません、火が弱いです…")
		return
	if need == "grate":
		return
	# 皿から生の肉を網にのせる
	if my_on_grill.size() < 5:
		for pl in _plates_given:
			if is_instance_valid(pl) and pl.container == table and not pl.meats.is_empty():
				var m: Meat = pl.meats[0]
				var a := randf() * TAU
				g.place_meat(m, Vector2(cos(a), sin(a)) * randf_range(0.0, 0.1), randf() * TAU)
				_flip_at[m] = randf_range(0.5, 0.95)
				_flipped_once[m] = false
				return
	# 全部食べたら追加注文かお会計
	if raw_left == 0 and my_on_grill.is_empty() and _sum(delivered) >= _sum(order):
		if rounds < 2 and randf() < 0.45:
			_call("call_order", "追加の注文いいですか？")
		else:
			_call("call_bill", "お会計お願いします")


func _food_score() -> float:
	if scores.is_empty():
		return 0.5
	var s := 0.0
	for v in scores:
		s += v
	return s / scores.size()


func _pay() -> void:
	var total := 0
	for c in delivered:
		total += MeatData.item_price(c) * delivered[c]
	total = int(round(total * (0.85 + 0.15 * _food_score()) / 10.0)) * 10
	Game.add_money(total)
	var stars := clampf(roundf(1.0 + 4.0 * (0.5 * clampf(service, 0.0, 1.0) + 0.5 * _food_score())), 1.0, 5.0)
	Game.main.record_visit(total, stars)
	Game.say("テーブル%d お会計 %s　評価 %s" % [table.index, Game.yen(total), _stars(stars)])
	say("ごちそうさまでした！ " + _stars(stars))
	_leave(false)


func _stars(s: float) -> String:
	return "★".repeat(int(s)) + "☆".repeat(5 - int(s))


func _leave(angry: bool) -> void:
	if OS.is_debug_build():
		print("party leave angry=%s state=%s patience=%.1f order=%s delivered=%s" % [angry, state, patience, order, delivered])
	if angry:
		var paid := 0
		for c in delivered:
			paid += int(MeatData.item_price(c) * delivered[c] * 0.5)
		if paid > 0:
			Game.add_money(paid)
		Game.main.record_visit(paid, 1.0)
		Game.say("テーブル%dのお客さんが怒って帰った…" % table.index)
	state = "leave"
	for m in table.grill.meats.duplicate():
		if _flip_at.has(m):
			m.detach()
			m.queue_free()
	for i in members.size():
		var m := members[i]
		m.stand()
		m.path = [table.chair_approach(i)]
		m.path.append_array(Game.main.nav_path(table.chair_approach(i), Game.main.door_pos))
	table.party = null
	table.set_dirty()
	for d in _drinks.keys():
		if is_instance_valid(d):
			d.drink = ""
			d.level = 0.0
			d.foam = 0.0
			d.empty_used = true
			d.refresh()


func _update_bubble() -> void:
	if members.is_empty():
		return
	_bubble.position = members[0].position + Vector3(0, 2.0 if not members[0].seated else 1.8, 0)
	var t := ""
	if _say_t > 0.0:
		t = _said
	elif state == "call_order" or state == "call_bill" or need != "":
		t = "（呼んでいる）" + Game.bar(patience / 70.0, 8)
	_bubble.text = t
