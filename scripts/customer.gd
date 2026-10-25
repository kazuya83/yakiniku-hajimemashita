class_name Customer
extends Node3D
## カウンターのお客さん。注文した部位を焼いて出すと食べて、焼き加減で評価する

var seat: Seat
var state := "walk_in"
var path: Array[Vector3] = []
var cut := "karubi"
var count := 2
var drink := ""
var drink_served := false
var served := 0
var eaten := 0
var scores: Array[float] = []
var patience := 160.0
var max_patience := 160.0
var _eat_t := 0.0
var _bubble: Label3D
var _person: Person
var _door := Vector3.ZERO
var _mood := ""
var _mood_t := 0.0
var ctype := "normal"
var by_staff := false   # アルバイトが焼いて出した


func setup(s: Seat, c: String, n: int, door: Vector3) -> Customer:
	seat = s
	_door = door
	ctype = Game.pick_type(false)
	cut = c
	if ctype == "gourmet" and Game.has("premium") and randf() < 0.7:
		cut = MeatData.PREMIUM.pick_random()
	count = n
	max_patience = 160.0 * Game.type_patience(ctype)
	patience = max_patience
	if randf() < 0.55:
		drink = ["beer", "beer", "highball", "oolong"].pick_random()
	path = Game.main.nav_path(door, s.stool_pos + Vector3(0, 0, 0.35))
	path.append(s.stool_pos)
	return self


func _ready() -> void:
	_person = Person.new()
	add_child(_person)
	_person.position = _door
	_bubble = Build.label(_person, "", Vector3(0, 2.05, 0), 44)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.outline_size = 12
	_bubble.outline_modulate = Color(0, 0, 0, 0.8)


func is_seated() -> bool:
	return state == "waiting" or state == "eating"


func order_text() -> String:
	var t := "%s %d枚" % [MeatData.CUTS[cut].name, count]
	if drink != "":
		t += "＋" + MeatData.DRINKS[drink].name + ("（済）" if drink_served else "")
	return t


func offer_drink(d: Drink) -> void:
	if drink == "" or drink_served:
		_say("飲み物は頼んでないよ")
		return
	if d.drink != drink or d.level < 0.2:
		_say("それじゃないよ")
		return
	var s := d.score()
	scores.append(s)
	drink_served = true
	seat.add_drink(d)
	if drink == "beer":
		_say("泡がきれい！" if s > 0.8 else ("泡ばっかり…" if d.foam > d.level * 0.6 else "泡が少ないな"))
	else:
		_say("ありがとう！" if s > 0.7 else "ちょっと少ないね")


func _say(t: String) -> void:
	_mood = t
	_mood_t = 3.0


func offer(meats: Array) -> void:
	var took := 0
	for m in meats:
		if served >= count:
			break
		if m.cut != cut:
			_say("それ、頼んでないよ")
			continue
		seat.add_meat(m)
		served += 1
		took += 1
	if took > 0:
		state = "eating"
		if served >= count:
			_say("ありがとう！")


func _process(dt: float) -> void:
	_mood_t -= dt
	match state:
		"walk_in", "leave":
			_walk(dt)
		"waiting", "eating":
			_seated(dt)
	_update_bubble()


func _walk(dt: float) -> void:
	_person.path = path
	if _person.walk(dt):
		if state == "walk_in":
			state = "waiting"
			_person.sit(0.0)
			_say(("いつもの、%sを%d枚%s！" if ctype == "regular" else "%sを%d枚%s！") % [MeatData.CUTS[cut].name, count, ("と" + MeatData.DRINKS[drink].name + "ください") if drink != "" else "ください"])
		else:
			Game.main.customer_left(self)
			queue_free()


func _seated(dt: float) -> void:
	if served < count or (drink != "" and not drink_served):
		patience -= dt * (0.5 if state == "eating" else 1.0)
		if patience <= 0.0:
			_say("もう帰る！")
			_finish(true)
			return
	if not seat.meats.is_empty():
		_eat_t += dt
		_person.head.position.y = 1.66 - absf(sin(_eat_t * 4.0)) * 0.03
		if _eat_t > 3.5:
			_eat_t = 0.0
			var m: Meat = seat.meats.pop_front()
			var s := m.score()
			scores.append(s)
			eaten += 1
			_say(_reaction(m, s))
			m.queue_free()
	elif served >= count and eaten >= count and (drink == "" or drink_served):
		_finish(false)


func _reaction(m: Meat, s: float) -> String:
	if ctype == "complainer" and s < 0.85 and not m.dropped:
		return ["焼き方がなってない！", "これでお金取るの？", "店長呼んで！"].pick_random()
	if ctype == "gourmet" and s >= 0.9:
		return "見事な火入れだ…！"
	if m.dropped:
		return "床に落ちたやつじゃない…？"
	match m.state_word():
		"焦げ":
			return "焦げてて苦い…"
		"生":
			return "まだ生だよ…"
		"レア":
			return "ちょっと生っぽいかな" if s < 0.8 else "レアでうまい！"
		"よく焼き":
			return "ちょっと硬いかも"
	return "うまい！最高の焼き加減！" if s > 0.85 else "うん、おいしい"


func _finish(angry: bool) -> void:
	var avg := 0.0
	for s in scores:
		avg += s
	avg = avg / maxf(scores.size(), 1.0)
	var stars := 1.0 if angry and scores.is_empty() else clampf(roundf(1.0 + avg * 4.0) - (1.0 if angry else 0.0), 1.0, 5.0)
	if not angry:
		stars = Game.type_stars(ctype, stars, avg)
	var price: int = MeatData.CUTS[cut].price
	var base := price / 4.0 * 1.5 * eaten
	if drink_served:
		base += MeatData.DRINKS[drink].price
	var pay := int(round(base * (0.7 + 0.3 * avg) * Game.type_pay(ctype, avg) / 10.0)) * 10
	if pay > 0:
		Game.add_money(pay)
	Game.main.record_visit(pay, stars)
	if not angry:
		_say("ごちそうさま！ " + "★".repeat(int(stars)) + "☆".repeat(5 - int(stars)))
	Game.say("お会計 %s　評価 %s" % [Game.yen(pay), "★".repeat(int(stars)) + "☆".repeat(5 - int(stars))])
	seat.clear()
	seat.customer = null
	state = "leave"
	_person.stand()
	path = Game.main.nav_path(_person.position + Vector3(0, 0, 0.35), Game.main.door_pos)


func _update_bubble() -> void:
	var t := ""
	if _mood_t > 0.0:
		t = _mood
	elif is_seated():
		var tag: String = Game.TYPE_NAMES[ctype]
		t = "%s%s  %d/%d\n%s" % [("【%s】" % tag) if tag != "" else "", order_text(), eaten, count, Game.bar(patience / max_patience, 8)]
	_bubble.text = t
	_bubble.modulate = Color(1, 0.55, 0.45) if is_seated() and patience < max_patience * 0.3 else Color.WHITE
