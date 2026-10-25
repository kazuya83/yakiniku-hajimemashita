extends Node3D
## 店全体の進行（仕込み → 営業 → 閉店後）と、画質の切り替え

const SEAT_X := [-3.6, -1.6, 0.4]

var items_root: Node3D
var player: Player
var hud: Hud
var env: Environment
var grills: Array[Grill] = []
var seats: Array[Seat] = []
var shadow_lights: Array[Light3D] = []
var sign_board: OpenSign
var door_pos := Vector3(4.6, 0, 4.1)

var phase := "prep"
var day_time := 0.0
var day_length := 600.0
var _spawn_t := 6.0
var _customers: Array[Customer] = []
var day_sales := 0
var day_visits := 0
var day_stars: Array[float] = []
var _start_money := 0


func _ready() -> void:
	Game.main = self
	_setup_input()
	_build_environment()
	items_root = Node3D.new()
	items_root.name = "Items"
	add_child(items_root)
	ShopBuilder.build(self)
	player = Player.new()
	add_child(player)
	player.position = Vector3(-0.6, 0.05, -2.9)
	player.rotation.y = PI
	hud = Hud.new()
	add_child(hud)
	Game.hud = hud
	apply_quality(Game.quality)
	_start_money = Game.money
	Game.say("仕込みをしたら、入口の札をEでひっくり返して開店！")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			add_child(load("res://scripts/dev_shot.gd").new())
		if a == "--walk":
			add_child(load("res://scripts/dev_walk.gd").new())
		if a == "--test":
			add_child(load("res://scripts/dev_test.gd").new())


func _setup_input() -> void:
	var keys := {
		"move_f": [KEY_W, KEY_UP], "move_b": [KEY_S, KEY_DOWN], "move_l": [KEY_A, KEY_LEFT], "move_r": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "use": [KEY_E], "pause": [KEY_ESCAPE], "help": [KEY_H], "next_day": [KEY_ENTER, KEY_KP_ENTER],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			# 配列（物理キー）と文字（キーボード配列どおり）の両方で受け付ける
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
			var ev2 := InputEventKey.new()
			ev2.keycode = k
			InputMap.action_add_event(a, ev2)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.015, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.7, 0.55)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.9, 0.86, 0.8)
	env.volumetric_fog_length = 20.0
	env.sdfgi_use_occlusion = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func apply_quality(q: String) -> void:
	Game.quality = q
	env.sdfgi_enabled = q == "high"
	env.ssao_enabled = q != "low"
	env.ssil_enabled = q == "high"
	env.volumetric_fog_enabled = q == "high"
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X if q == "high" else (Viewport.MSAA_2X if q == "mid" else Viewport.MSAA_DISABLED)
	vp.scaling_3d_scale = 0.75 if q == "low" else 1.0
	for l in shadow_lights:
		l.shadow_enabled = q != "low"
	Game.say("画質: " + {"low": "低", "mid": "中", "high": "高"}[q])


func open_shop() -> void:
	phase = "open"
	day_time = 0.0
	_spawn_t = 4.0
	sign_board.refresh()
	Game.say("開店！いらっしゃいませ！")


func _process(dt: float) -> void:
	if phase == "open":
		day_time += dt
		_spawn_t -= dt
		if _spawn_t <= 0.0:
			_spawn_t = randf_range(18.0, 34.0) / clampf(Game.rating() / 3.0, 0.6, 1.6)
			_spawn_customer()
		if day_time >= day_length:
			phase = "closing"
			sign_board.refresh()
			Game.say("閉店時間！残ったお客さんを見送ろう")
	elif phase == "closing" and _customers.is_empty():
		_show_summary()
	_update_status()


func _spawn_customer() -> void:
	var free: Array[Seat] = []
	for s in seats:
		if s.customer == null:
			free.append(s)
	if free.is_empty():
		return
	var s: Seat = free.pick_random()
	var c := Customer.new().setup(s, MeatData.ORDER.pick_random(), randi_range(2, 3), door_pos)
	c.position = door_pos
	add_child(c)
	s.customer = c
	_customers.append(c)


func customer_left(c: Customer) -> void:
	_customers.erase(c)


func record_visit(pay: int, stars: float) -> void:
	day_sales += pay
	day_visits += 1
	day_stars.append(stars)
	Game.add_review(stars)


func _clock() -> String:
	var mins := int(17 * 60 + clampf(day_time / day_length, 0.0, 1.0) * 6 * 60)
	return "%02d:%02d" % [mins / 60, mins % 60]


func _update_status() -> void:
	var ph: String = {"prep": "仕込み中", "open": "営業中", "closing": "閉店作業中", "summary": "閉店"}[phase]
	var r := Game.rating()
	hud.set_status("%d日目　%s　%s\n所持金 %s\n評判 %s %.1f" % [Game.day, _clock() if phase != "prep" else "17:00", ph, Game.yen(Game.money), "★".repeat(int(round(r))) + "☆".repeat(5 - int(round(r))), r])
	var lines: Array[String] = []
	for i in seats.size():
		var c := seats[i].customer
		if c and c.is_seated():
			lines.append("カウンター%d: %s（%d/%d）" % [i + 1, c.order_text(), c.eaten, c.count])
	hud.set_orders("\n".join(lines))


func _show_summary() -> void:
	phase = "summary"
	var avg := 0.0
	for s in day_stars:
		avg += s
	avg = avg / maxf(day_stars.size(), 1.0)
	var t := "%d日目 おつかれさま！\n\n売上　%s\nお客さん　%d人\n今日の評価　%.1f\n仕入れ・炭代を引いた所持金の増減　%s\n\n冷蔵庫の肉は毎朝新しく届きます。" % [Game.day, Game.yen(day_sales), day_visits, avg, Game.yen(Game.money - _start_money)]
	hud.show_summary(t)


func next_day() -> void:
	if not hud.summary_visible():
		return
	hud.hide_summary()
	Game.day += 1
	phase = "prep"
	day_time = 0.0
	day_sales = 0
	day_visits = 0
	day_stars.clear()
	_start_money = Game.money
	sign_board.refresh()
	Game.say("%d日目の朝。仕込みを始めよう" % Game.day)
