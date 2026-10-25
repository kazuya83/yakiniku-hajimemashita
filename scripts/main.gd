extends Node3D
## 店全体の進行（仕込み → 営業 → 閉店後）と、画質の切り替え

const SEAT_X := [-3.6, -1.6, 0.4]

var items_root: Node3D
var player: Player
var hud: Hud
var env: Environment
var grills: Array[Grill] = []
var seats: Array[Seat] = []
var tables: Array[DiningTable] = []
var _parties: Array[TableParty] = []
var shadow_lights: Array[Light3D] = []
var sign_board: OpenSign
var door_pos := Vector3(4.6, 0, 4.1)
var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var mats := {}
var room_max_x := ShopBuilder.W / 2
var nav: NavigationRegion3D
var build: BuildMode
var menu_label: Label3D
var staff: Array[Staff] = []
var clocked_in := false
var _clock_in_at := ""
var prep_min := 0.0       # 出社前・仕込み中の時計（分）
const DAY_START := 16 * 60 + 35
const MIN_PER_SEC := 1.0 / 1.5

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
	OutsideBuilder.build(self)
	_setup_nav()
	player = Player.new()
	add_child(player)
	_go_home()
	hud = Hud.new()
	add_child(hud)
	Game.hud = hud
	build = BuildMode.new()
	add_child(build)
	apply_quality(Game.quality)
	_start_money = Game.money
	Game.say("あなたは焼肉屋の店長。家を出たら、向かいの店のタイムカードを押して出社しよう")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			add_child(load("res://scripts/dev_shot.gd").new())
		if a == "--walk":
			add_child(load("res://scripts/dev_walk.gd").new())
		if a == "--test":
			add_child(load("res://scripts/dev_test.gd").new())


## お客さんの歩き道（床のナビメッシュ）。設備を動かしたら作り直す
func _setup_nav() -> void:
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.1)
	NavigationServer3D.map_set_cell_height(map, 0.1)
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = &"navsrc"
	nm.cell_size = 0.1
	nm.cell_height = 0.1
	nm.agent_radius = 0.3
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.2
	nav.navigation_mesh = nm
	add_child(nav)
	rebake()


func rebake() -> void:
	nav.bake_navigation_mesh(false)


func nav_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		var pts := NavigationServer3D.map_get_path(map, from, to, true)
		for p in pts:
			out.append(Vector3(p.x, 0, p.z))
	if out.is_empty() or out[-1].distance_to(Vector3(to.x, 0, to.z)) > 0.6:
		out.append(Vector3(to.x, 0, to.z))
	return out


func _setup_input() -> void:
	var keys := {
		"move_f": [KEY_W, KEY_UP], "move_b": [KEY_S, KEY_DOWN], "move_l": [KEY_A], "move_r": [KEY_D], "turn_l": [KEY_LEFT], "turn_r": [KEY_RIGHT],
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
	# 夕方の空
	var sky_m := ProceduralSkyMaterial.new()
	sky_m.sky_top_color = Color(0.12, 0.16, 0.32)
	sky_m.sky_horizon_color = Color(0.95, 0.5, 0.25)
	sky_m.ground_horizon_color = Color(0.3, 0.2, 0.15)
	sky_m.ground_bottom_color = Color(0.05, 0.04, 0.04)
	sky_m.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_m
	env.background_mode = Environment.BG_SKY
	env.sky = sky
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
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.22, -PI / 2 - 0.4, 0)
	sun.light_color = Color(1.0, 0.6, 0.35)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	shadow_lights.append(sun)


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


## 朝は自宅の前から（毎日歩いて出社する）
func _go_home() -> void:
	player.global_position = OutsideBuilder.HOME_POS
	player.rotation.y = -PI / 2 - 0.5
	player.cam.rotation.x = 0.0
	prep_min = DAY_START


func now_min() -> int:
	if phase == "prep":
		return int(prep_min)
	return int(17 * 60 + clampf(day_time / day_length, 0.0, 1.0) * (7 if Game.has("extend") else 6) * 60)


func clock_in() -> void:
	if clocked_in:
		return
	clocked_in = true
	var now := now_min()
	_clock_in_at = "%02d:%02d" % [now / 60, now % 60]
	if staff.is_empty():
		Game.say("出社！入口の横のシフト表で、アルバイトを雇える（E）")
	else:
		Game.say("出社！アルバイト%d人もそろっている。仕込みをしたら札をひっくり返して開店しよう" % staff.size())


func _prep_clock(dt: float) -> void:
	if phase != "prep":
		return
	prep_min += dt * MIN_PER_SEC


## アルバイトを雇う（同じ担当を何人でも）
func hire(role: String) -> Staff:
	var st := Staff.new()
	st.role = role
	add_child(st)
	staff.append(st)
	Game.say("%sのアルバイトを雇った（日給 %s）" % [Game.ROLES[role].name, Game.yen(Game.ROLES[role].wage)])
	return st


func fire(role: String) -> bool:
	for i in range(staff.size() - 1, -1, -1):
		if staff[i].role == role:
			staff[i].leave()
			staff.remove_at(i)
			Game.say("%sのアルバイトに辞めてもらった" % Game.ROLES[role].name)
			return true
	return false


func staff_count(role: String) -> int:
	return staff.filter(func(x): return x.role == role).size()


func wages() -> int:
	var w := 0
	for st in staff:
		w += Game.ROLES[st.role].wage
	return w


func clock_in_text() -> String:
	return _clock_in_at


func open_shop() -> void:
	if build.active:
		build.toggle()
	day_length = 700.0 if Game.has("extend") else 600.0
	phase = "open"
	day_time = 0.0
	_spawn_t = 4.0
	sign_board.refresh()
	Game.say("開店！いらっしゃいませ！")


func _process(dt: float) -> void:
	_prep_clock(dt)
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
	elif phase == "closing" and _customers.is_empty() and _parties.is_empty():
		_show_summary()
	_update_status()


func _spawn_customer() -> void:
	var free_tables: Array[DiningTable] = []
	for t in tables:
		if t.party == null and t.is_clean():
			free_tables.append(t)
	if not free_tables.is_empty() and randf() < 0.55:
		var t: DiningTable = free_tables.pick_random()
		var pt := TableParty.new().setup(t, randi_range(2, 4), door_pos)
		add_child(pt)
		t.party = pt
		_parties.append(pt)
		return
	var free: Array[Seat] = []
	for s in seats:
		if s.customer == null:
			free.append(s)
	if free.is_empty():
		return
	var s: Seat = free.pick_random()
	var c := Customer.new().setup(s, MeatData.ORDER.pick_random(), randi_range(2, 3), door_pos)
	add_child(c)
	s.customer = c
	_customers.append(c)


## レジ（お店づくりで動かしていても見つける）。なければ席でお会計
func register() -> Register:
	var a := get_tree().get_nodes_in_group("register")
	return a[0] if not a.is_empty() else null


func customer_left(c: Customer) -> void:
	_customers.erase(c)


func party_left(p: TableParty) -> void:
	_parties.erase(p)


func record_visit(pay: int, stars: float) -> void:
	day_sales += pay
	day_visits += 1
	day_stars.append(stars)
	Game.add_review(stars)


func _clock() -> String:
	var mins := now_min()
	return "%02d:%02d" % [mins / 60, mins % 60]


func _update_status() -> void:
	var ph: String = {"prep": "仕込み中", "open": "営業中", "closing": "閉店作業中", "summary": "閉店"}[phase]
	var r := Game.rating()
	if not clocked_in and phase != "summary":
		ph = "出社前（入口のタイムカードを押そう）"
	var st_line := "アルバイト なし（シフト表で雇える）"
	if not staff.is_empty():
		var parts: Array[String] = []
		for role in Game.ROLES:
			var n := staff_count(role)
			if n > 0:
				parts.append("%s%d" % [Game.ROLES[role].name, n])
		st_line = "アルバイト " + "・".join(parts)
	hud.set_status("%d日目　%s　%s\n所持金 %s\n%s\n評判 %s %.1f　%s\nきれいな皿 %d　ジョッキ %d　洗い物 %d" % [Game.day, _clock(), ph, Game.yen(Game.money), st_line, "★".repeat(int(round(r))) + "☆".repeat(5 - int(round(r))), r, Game.level_text(), Game.clean_plates, Game.clean_jugs, Game.dirty_plates + Game.dirty_jugs])
	var lines: Array[String] = []
	for i in seats.size():
		var c := seats[i].customer
		if c and c.is_seated():
			lines.append("カウンター%d: %s（%d/%d）" % [i + 1, c.order_text(), c.eaten, c.count])
	for t in tables:
		if t.party and t.party.state != "walk_in":
			var pt := t.party
			var line := "テーブル%d: %s" % [t.index, pt.status_text()]
			if not pt.ticket.is_empty():
				line += "\n　伝票: " + pt.ticket_text()
			lines.append(line)
		elif t.party == null and not t.items.is_empty():
			lines.append("テーブル%d: 皿とジョッキを下げてください" % t.index)
		elif t.party == null and t.dirty:
			lines.append("テーブル%d: テーブルを拭いてください" % t.index)
	var reg := register()
	if reg and not reg.queue.is_empty():
		var w := 0
		for q in reg.queue:
			if is_instance_valid(q) and q.at_register():
				w += 1
		lines.append("レジ: %d組がお会計待ち%s" % [reg.queue.size(), "（レジでE）" if w > 0 else "（向かっている）"])
	hud.set_orders("\n".join(lines))


func _show_summary() -> void:
	phase = "summary"
	var avg := 0.0
	for s in day_stars:
		avg += s
	avg = avg / maxf(day_stars.size(), 1.0)
	var t := "%d日目 おつかれさま！\n\n売上　%s\nお客さん　%d人\n今日の評価　%.1f\n" % [Game.day, Game.yen(day_sales), day_visits, avg]
	var w := wages()
	if w > 0:
		Game.add_money(-w)
		t += "アルバイト代　-%s（%d人）\n" % [Game.yen(w), staff.size()]
	t += "仕入れ・炭代・アルバイト代を引いた所持金の増減　%s\n" % Game.yen(Game.money - _start_money)
	hud.show_summary(t)


func next_day() -> void:
	if not hud.summary_visible():
		return
	hud.hide_summary()
	Game.day += 1
	clocked_in = false
	_go_home()
	for st in staff:
		st.reset_day()
	phase = "prep"
	day_time = 0.0
	day_sales = 0
	day_visits = 0
	day_stars.clear()
	_start_money = Game.money
	sign_board.refresh()
	var msg := "%d日目の朝。" % Game.day
	var waste := Game.discard_expired()
	if not waste.is_empty():
		var parts := []
		for c in waste:
			parts.append("%s%d枚" % [MeatData.CUTS[c].name, waste[c]])
		msg += "\n賞味期限切れで廃棄: " + "・".join(parts)
	var i := 0
	for c in Game.orders:
		for k in Game.orders[c]:
			var b := SupplyBox.new().setup(c)
			items_root.add_child(b)
			b.global_position = Vector3(3.3 + (i % 3) * 0.48, (i / 3) * 0.25, -3.95)
			i += 1
	if i > 0:
		msg += "\n段ボールが%d箱届いた（厨房の右奥）" % i
	Game.orders.clear()
	msg += "\n家を出た。お店でタイムカードを押そう"
	Game.say(msg)
