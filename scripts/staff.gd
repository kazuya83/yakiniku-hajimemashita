class_name Staff
extends Node3D
## アルバイト。担当（role）ごとに自分で考えて動く
##  cook  … カウンターのお客さんの肉を焼いて出す（飲み物も）
##  hall  … テーブル席の注文取り・肉と飲み物を運ぶ・お会計・網の交換と炭
##  clean … 帰ったテーブルの皿を下げて拭く・洗い物

const COOK_TIME := 22.0
const SHIRTS := {"cook": Color(0.08, 0.08, 0.09), "hall": Color(0.55, 0.1, 0.08), "clean": Color(0.15, 0.3, 0.45)}

var role := "clean"
var person: Person
var job := ""
var target: Node = null
var _item := ""        # ホール担当が運んでいる物（部位か飲み物）
var _t := 0.0
var _think := 0.0
var _bubble: Label3D
var _said := ""
var _say_t := 0.0
var _tray: Node3D
var _leaving := false


func _ready() -> void:
	person = Person.new()
	person.look = "staff_f" if role == "hall" else "staff_m"
	add_child(person)
	person.position = Game.main.door_pos
	person.speed = 1.7
	if not person.real:
		(person.model.get_child(0) as MeshInstance3D).material_override = Build.mat(SHIRTS[role], 0.7)
		if role == "cook":
			Build.cyl(person.head, 0.128, 0.128, 0.035, Vector3(0, 0.05, 0), Build.mat(Color(0.95, 0.95, 0.95), 0.8), false, 24)
		Build.box(person.model, Vector3(0.36, 0.6, 0.02), Vector3(0, 1.0, 0.205), Build.mat(Color(0.12, 0.1, 0.08), 0.8), false)
	var name_l := Build.label(person, "バイト（%s）" % Game.ROLES[role].name, Vector3(0, 1.95, 0), 30, Color(0.8, 0.95, 1.0))
	name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble = Build.label(person, "", Vector3(0, 2.15, 0), 40)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.outline_size = 10
	_bubble.outline_modulate = Color(0, 0, 0, 0.8)
	# 運んでいるお盆（ホール担当）
	_tray = Node3D.new()
	_tray.position = Vector3(0.0, 1.0, -0.42) if person.real else Vector3(0.0, 1.1, 0.35)
	_tray.visible = false
	person.model.add_child(_tray)
	Build.cyl(_tray, 0.17, 0.17, 0.015, Vector3.ZERO, Build.mat(Color(0.15, 0.1, 0.07), 0.6))
	Build.cyl(_tray, 0.11, 0.09, 0.03, Vector3(0, 0.02, 0), Build.mat(Color(0.95, 0.95, 0.93), 0.4))
	_go(Vector3(1.0, 0, -2.6) if role != "hall" else Vector3(3.0, 0, 0.8))


func say(t: String) -> void:
	_said = t
	_say_t = 4.0


## 次の日の朝：持ち場に戻る
func reset_day() -> void:
	job = ""
	target = null
	_tray.visible = false
	person.stand()
	person.path.clear()


## 辞めてもらう：入口まで歩いて帰る
func leave() -> void:
	_leaving = true
	_tray.visible = false
	person.stand()
	_go(Game.main.door_pos)


func _go(to: Vector3) -> void:
	person.path = Game.main.nav_path(person.position, to)


func _front(n: Node3D, d: float = 0.75) -> Vector3:
	return n.global_position + n.global_transform.basis.z * d


func _shop_find(cls: String) -> Node3D:
	var a := Game.main.get_node("Shop").find_children("*", cls, true, false)
	return a[0] if not a.is_empty() else null


## レジの内側（お客さんの反対側）
func _behind(reg: Node3D) -> Vector3:
	var p := reg.global_position - reg.global_transform.basis.z * 0.6
	return Vector3(p.x, 0, p.z)


func _table_spot(t: DiningTable) -> Vector3:
	return t.global_position + Vector3(0, 0, 1.15).rotated(Vector3.UP, t.rotation.y)


func _process(dt: float) -> void:
	if person.pose:
		person.pose.carry = _tray.visible
		person.pose.work = true
	_say_t -= dt
	_bubble.text = _said if _say_t > 0.0 else ""
	if _leaving:
		if person.walk(dt):
			queue_free()
		return
	if not person.path.is_empty():
		person.walk(dt)
		return
	match role:
		"cook":
			_cook(dt)
		"hall":
			_hall(dt)
		"clean":
			_clean(dt)


# ---- 焼き担当 ----
func _cook(dt: float) -> void:
	match job:
		"":
			_think -= dt
			if _think > 0.0:
				return
			_think = 1.0
			for s in Game.main.seats:
				var c: Customer = s.customer
				if c and c.state == "waiting" and c.served == 0 and not _claimed(c):
					job = "counter"
					target = c
					_t = 0.0
					_go(Vector3(s.stool_pos.x, 0, -1.85))
					return
		"counter":
			person.rotation.y = PI
			var c: Customer = target if is_instance_valid(target) else null
			if c == null or not c.is_seated():
				job = ""
				return
			_t += dt
			if not person.real:
				person.raise_hand(int(_t * 2.0) % 2 == 0)
			if _t >= COOK_TIME:
				person.raise_hand(false)
				_serve_counter(c)
				job = ""


## ほかのアルバイトがもう担当しているか
func _claimed(n: Node) -> bool:
	for st in Game.main.staff:
		if st != self and st.target == n and st.job != "":
			return true
	return false


func _serve_counter(c: Customer) -> void:
	c.by_staff = true
	var meats: Array = []
	for i in c.count:
		if not Game.take_stock(c.cut, 1):
			break
		var me := Meat.new().setup(c.cut)
		Game.main.items_root.add_child(me)
		me.sear = [randf_range(0.6, 0.8), randf_range(0.6, 0.8)]
		me.core = lerpf(me.data.ideal.x, me.data.ideal.y, randf_range(0.25, 0.75))
		meats.append(me)
	if meats.is_empty():
		say("%sが切れてます！" % MeatData.CUTS[c.cut].name)
		Game.say("焼き担当「店長、%sの在庫がありません！」" % MeatData.CUTS[c.cut].name)
		return
	c.offer(meats)
	if c.drink != "" and Game.clean_jugs > 0:
		Game.clean_jugs -= 1
		var d := Drink.new()
		Game.main.items_root.add_child(d)
		d.drink = c.drink
		d.level = 0.68
		d.foam = 0.27 if c.drink == "beer" else 0.0
		c.offer_drink(d)
	say("お待たせしました！")


# ---- ホール担当 ----
func _hall(dt: float) -> void:
	match job:
		"":
			_think -= dt
			if _think > 0.0:
				return
			_think = 0.8
			_hall_pick()
		"order", "bill", "fix":
			var pt: TableParty = target if is_instance_valid(target) else null
			if pt == null or pt.state == "leave":
				job = ""
				return
			_t += dt
			if _t < 2.5:
				return
			match job:
				"order":
					if pt.state == "call_order":
						pt.members[0].raise_hand(false)
						pt.staff_take_order()
						say("ご注文うけたまわりました！")
				"bill":
					if pt.state == "call_bill":
						pt.on_use(null)
				"fix":
					var g := pt.table.grill
					if g.grate:
						g.grate.dirt = 0.0
						g.grate.add_dirt(0.0)
					g.coal = maxf(g.coal, 0.9)
					say("網と炭、交換しました！")
			job = ""
		"register":
			var reg: Register = target if is_instance_valid(target) else null
			if reg == null or not reg.waiting():
				job = ""
				return
			person.rotation.y = atan2(-(reg.global_position.x - person.position.x), -(reg.global_position.z - person.position.z))
			_t += dt
			if _t >= 2.5:
				reg.checkout()
				say("ありがとうございました！")
				job = ""
		"fetch":
			# 冷蔵庫かドリンク台で用意して、テーブルへ
			_t += dt
			if _t < 2.0:
				return
			var pt: TableParty = target if is_instance_valid(target) else null
			if pt == null or pt.state == "leave" or not pt.wants_key(_item):
				job = ""
				return
			if not _prepare(_item):
				job = ""
				return
			_tray.visible = true
			job = "deliver"
			_go(_table_spot(pt.table))
		"deliver":
			var pt: TableParty = target if is_instance_valid(target) else null
			_tray.visible = false
			job = ""
			if pt == null or pt.state == "leave":
				return
			var it := _make_item(_item)
			if it and pt.table.put_plate(it):
				if pt.wants(it):
					pt.on_item(it)
				say("お待たせしました！")


## ホールで次にやることを決める（レジのお会計がいちばん先）
func _hall_pick() -> void:
	var reg: Register = Game.main.register()
	if reg and reg.waiting() and not _claimed(reg):
		job = "register"
		target = reg
		_t = 0.0
		_go(_behind(reg))
		return
	for t in Game.main.tables:
		var pt: TableParty = t.party
		if pt == null or _claimed(pt):
			continue
		if pt.state == "call_order":
			_start("order", pt)
			return
		if pt.state == "call_bill":
			_start("bill", pt)
			return
		if pt.need != "":
			_start("fix", pt)
			return
	for t in Game.main.tables:
		var pt: TableParty = t.party
		if pt == null or not (pt.state == "wait_food" or pt.state == "eating"):
			continue
		var k := pt.next_wanted(_others_carrying(pt))
		if k == "" or (not MeatData.is_drink(k) and Game.stock_count(k) < 4):
			continue
		target = pt
		_item = k
		job = "fetch"
		_t = 0.0
		if MeatData.is_drink(k):
			var dc: Node3D = Game.main.get_node("Shop/DrinkCounter")
			_go(dc.global_position - dc.global_transform.basis.x * 0.8)
		else:
			_go(_front(_shop_find("Fridge"), 0.9))
		return


func _start(j: String, pt: TableParty) -> void:
	job = j
	target = pt
	_t = 0.0
	_go(_table_spot(pt.table))


## ほかのホール担当が運んでいる物
func _others_carrying(pt: TableParty) -> Dictionary:
	var d := {}
	for st in Game.main.staff:
		if st != self and st.target == pt and (st.job == "fetch" or st.job == "deliver"):
			d[st._item] = d.get(st._item, 0) + 1
	return d


## 在庫・皿・ジョッキを使って用意する
func _prepare(k: String) -> bool:
	if MeatData.is_drink(k):
		if Game.clean_jugs <= 0:
			say("ジョッキが足りません！")
			return false
		Game.clean_jugs -= 1
		return true
	if Game.clean_plates <= 0:
		say("お皿が足りません！")
		return false
	if not Game.take_stock(k, 4):
		say("%sが切れてます！" % MeatData.CUTS[k].name)
		return false
	Game.clean_plates -= 1
	return true


func _make_item(k: String) -> Item:
	if MeatData.is_drink(k):
		var d := Drink.new()
		Game.main.items_root.add_child(d)
		d.drink = k
		d.level = 0.68
		d.foam = 0.27 if k == "beer" else 0.0
		d.refresh()
		return d
	var plate := Plate.new()
	Game.main.items_root.add_child(plate)
	for i in 4:
		var m := Meat.new().setup(k)
		Game.main.items_root.add_child(m)
		plate.add_meat(m)
	return plate


# ---- 片づけ担当 ----
func _sink() -> Node3D:
	var dw := _shop_find("Dishwasher")
	if dw and dw.running <= 0.0:
		return dw
	return _shop_find("Sink")


func _clean(dt: float) -> void:
	match job:
		"":
			_think -= dt
			if _think > 0.0:
				return
			_think = 1.0
			for t in Game.main.tables:
				if t.party == null and not t.is_clean() and not _claimed(t):
					job = "table"
					target = t
					_t = 0.0
					_go(_table_spot(t))
					return
			if Game.dirty_plates + Game.dirty_jugs >= 3:
				job = "wash"
				_t = 0.0
				target = null
				_go(_front(_sink()))
		"table":
			var t: DiningTable = target if is_instance_valid(target) else null
			if t == null or t.party != null:
				job = ""
				return
			_t += dt
			if not person.real:
				person.raise_hand(int(_t * 3.0) % 2 == 0)
			if _t > 4.0:
				t.clear_all()
				t.finish_wipe()
				person.raise_hand(false)
				job = ""
		"wash":
			var s := _sink()
			if s is Dishwasher:
				s.start()
				job = ""
				return
			_t += dt
			if _t >= 1.6:
				_t = 0.0
				if Game.dirty_plates > 0:
					Game.dirty_plates -= 1
					Game.clean_plates += 1
				elif Game.dirty_jugs > 0:
					Game.dirty_jugs -= 1
					Game.clean_jugs += 1
				else:
					job = ""
