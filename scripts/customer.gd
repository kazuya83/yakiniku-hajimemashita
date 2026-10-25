class_name Customer
extends Node3D
## カウンターのお客さん。注文した部位を焼いて出すと食べて、焼き加減で評価する

var seat: Seat
var state := "walk_in"
var path: Array[Vector3] = []
var cut := "karubi"
var count := 2
var served := 0
var eaten := 0
var scores: Array[float] = []
var patience := 160.0
var max_patience := 160.0
var _eat_t := 0.0
var _bubble: Label3D
var _model: Node3D
var _head: MeshInstance3D
var _mood := ""
var _mood_t := 0.0
var _walk_t := 0.0


func setup(s: Seat, c: String, n: int, door: Vector3) -> Customer:
	seat = s
	cut = c
	count = n
	var lane_z := 0.25
	path = [Vector3(door.x - 0.3, 0, lane_z), Vector3(s.stool_pos.x, 0, lane_z), s.stool_pos]
	return self


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	var shirt := Build.mat(Color.from_hsv(randf(), randf_range(0.2, 0.6), randf_range(0.35, 0.8)), 0.8)
	var skin := Build.mat(Color(0.93, 0.78, 0.65).darkened(randf() * 0.25), 0.6)
	var hair := Build.mat(Color(0.06, 0.05, 0.04).lightened(randf() * 0.25), 0.7)
	var legs := Build.mat(Color(0.15, 0.16, 0.2), 0.8)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 0.75
	body.mesh = cap
	body.material_override = shirt
	body.position.y = 1.15
	_model.add_child(body)
	for s in [-0.09, 0.09]:
		Build.box(_model, Vector3(0.13, 0.8, 0.14), Vector3(s, 0.4, 0), legs, false)
	_head = Build.sphere(_model, 0.12, Vector3(0, 1.66, 0), skin)
	var h := Build.sphere(_head, 0.125, Vector3(0, 0.035, 0.015), hair)
	h.scale = Vector3(1, 0.8, 1)
	_bubble = Build.label(self, "", Vector3(0, 2.05, 0), 44)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.outline_size = 12
	_bubble.outline_modulate = Color(0, 0, 0, 0.8)


func is_seated() -> bool:
	return state == "waiting" or state == "eating"


func order_text() -> String:
	return "%s %d枚" % [MeatData.CUTS[cut].name, count]


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
	if path.is_empty():
		if state == "walk_in":
			state = "waiting"
			rotation.y = 0.0
			_model.position.y = -0.2
			_say("%sを%d枚ください！" % [MeatData.CUTS[cut].name, count])
		else:
			Game.main.customer_left(self)
			queue_free()
		return
	var target: Vector3 = path[0]
	var to := target - position
	to.y = 0
	var step := 1.3 * dt
	if to.length() <= step:
		position = Vector3(target.x, 0, target.z)
		path.pop_front()
	else:
		var d := to.normalized()
		position += d * step
		rotation.y = atan2(-d.x, -d.z)
		_walk_t += dt * 9.0
		_model.position.y = absf(sin(_walk_t)) * 0.03


func _seated(dt: float) -> void:
	if served < count:
		patience -= dt * (0.5 if state == "eating" else 1.0)
		if patience <= 0.0:
			_say("もう帰る！")
			_finish(true)
			return
	if not seat.meats.is_empty():
		_eat_t += dt
		_head.position.y = 1.66 - absf(sin(_eat_t * 4.0)) * 0.03
		if _eat_t > 3.5:
			_eat_t = 0.0
			var m: Meat = seat.meats.pop_front()
			var s := m.score()
			scores.append(s)
			eaten += 1
			_say(_reaction(m, s))
			m.queue_free()
			if eaten >= count:
				_finish(false)
	elif served >= count and eaten >= count:
		_finish(false)


func _reaction(m: Meat, s: float) -> String:
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
	var price: int = MeatData.CUTS[cut].price
	var pay := int(round(price * eaten * (0.7 + 0.3 * avg) / 10.0)) * 10
	if pay > 0:
		Game.add_money(pay)
	Game.main.record_visit(pay, stars)
	if not angry:
		_say("ごちそうさま！ " + "★".repeat(int(stars)) + "☆".repeat(5 - int(stars)))
	Game.say("お会計 %s　評価 %s" % [Game.yen(pay), "★".repeat(int(stars)) + "☆".repeat(5 - int(stars))])
	seat.clear()
	seat.customer = null
	state = "leave"
	_model.position.y = 0.0
	path = [Vector3(position.x, 0, 0.25), Vector3(Game.main.door_pos.x - 0.3, 0, 0.25), Game.main.door_pos]


func _update_bubble() -> void:
	var t := ""
	if _mood_t > 0.0:
		t = _mood
	elif is_seated():
		t = "%s  %d/%d\n%s" % [order_text(), eaten, count, Game.bar(patience / max_patience, 8)]
	_bubble.text = t
	_bubble.modulate = Color(1, 0.55, 0.45) if is_seated() and patience < max_patience * 0.3 else Color.WHITE
