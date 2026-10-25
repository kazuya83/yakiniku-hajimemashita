class_name OutsideBuilder
## 店の外の通り（歩道・道路・向かいの家並み・自宅・隣の空き区画）

const HOME_DOOR := Vector3(-22.0, 0, 15.2)
const HOME_POS := Vector3(-22.0, 0.05, 14.4)


static func build(main) -> void:
	var root := Node3D.new()
	root.name = "Outside"
	main.add_child(root)
	var asphalt := Build.noise_mat(Color(0.07, 0.07, 0.075), Color(0.13, 0.13, 0.135), 0.8, Vector3(2, 2, 2), 0.9, 21)
	var walk_m := Build.noise_mat(Color(0.32, 0.31, 0.3), Color(0.42, 0.41, 0.39), 0.5, Vector3(3, 3, 3), 0.85, 22)
	var white := Build.mat(Color(0.85, 0.85, 0.82), 0.7)
	var x0 := -34.0
	var x1 := 24.0
	var cx := (x0 + x1) / 2
	var lw := x1 - x0
	# 地面（店の床の外側）・歩道・道路・向かいの歩道
	Build.box(root, Vector3(lw, 0.1, 2.2), Vector3(cx, -0.05, 4.6 + 1.1), walk_m)
	Build.box(root, Vector3(lw, 0.1, 6.8), Vector3(cx, -0.07, 6.8 + 3.4), asphalt)
	Build.box(root, Vector3(lw, 0.1, 3.0), Vector3(cx, -0.05, 13.6 + 1.5), walk_m)
	# 縁石と白線
	for z in [6.8, 13.6]:
		Build.box(root, Vector3(lw, 0.06, 0.15), Vector3(cx, 0.0, z), Build.mat(Color(0.55, 0.55, 0.52), 0.8), false)
	var x := x0 + 1.0
	while x < x1:
		Build.box(root, Vector3(2.0, 0.005, 0.15), Vector3(x, -0.015, 10.2), white, false)
		x += 4.0
	# 横断歩道（店の前）
	for i in 7:
		Build.box(root, Vector3(0.45, 0.005, 6.4), Vector3(1.0 + i * 0.9, -0.015, 10.2), white, false)

	# 店の外観：軒・看板・のれん
	var facade := Build.mat(Color(0.1, 0.07, 0.05), 0.7)
	Build.box(root, Vector3(ShopBuilder.W + 0.3, 0.5, 0.4), Vector3(0, ShopBuilder.H + 0.25, 4.75), facade)
	var board := Build.box(root, Vector3(4.5, 0.8, 0.08), Vector3(1.0, 3.5, 5.0), Build.mat(Color(0.08, 0.05, 0.04), 0.6), false)
	board.name = "Board"
	var bl := Build.label(root, "焼肉屋はじめました", Vector3(1.0, 3.5, 5.05), 150, Color(1.0, 0.85, 0.55))
	bl.double_sided = false
	var glow := OmniLight3D.new()
	glow.position = Vector3(1.0, 3.0, 5.4)
	glow.light_color = Color(1.0, 0.75, 0.45)
	glow.light_energy = 1.2
	glow.omni_range = 5.0
	root.add_child(glow)
	var noren := Build.mat(Color(0.12, 0.13, 0.2), 0.9)
	for i in 3:
		Build.box(root, Vector3(0.44, 0.6, 0.01), Vector3(4.15 + i * 0.45, 1.92, 4.66), noren, false)
	var nl := Build.label(root, "焼 肉", Vector3(4.6, 1.95, 4.675), 140, Color(0.95, 0.93, 0.88))
	nl.double_sided = false
	for lx in [3.6, 5.6]:
		var lan := Build.sphere(root, 0.2, Vector3(lx, 2.1, 4.85), Build.glow_mat(Color(1.0, 0.25, 0.1), 2.0))
		lan.scale = Vector3(1, 1.3, 1)
	# 店の外壁（正面の板張り）
	for seg in [[-6.0, ShopBuilder.DOOR_X0], [ShopBuilder.DOOR_X1, 6.0]]:
		var w: float = seg[1] - seg[0]
		Build.box(root, Vector3(w, 1.0, 0.04), Vector3((seg[0] + seg[1]) / 2, 0.5, 4.62), facade, false)

	# 隣の空き区画（買うと店が広がる）
	var lot := Node3D.new()
	lot.name = "EmptyLot"
	root.add_child(lot)
	Build.box(lot, Vector3(4.0, 0.1, 9.0), Vector3(8.0, -0.05, 0.0), walk_m)
	for z in [-4.4, 4.4]:
		Build.box(lot, Vector3(4.0, 0.9, 0.05), Vector3(8.0, 0.45, z), Build.mat(Color(0.5, 0.5, 0.48), 0.6), false)
	Build.box(lot, Vector3(0.05, 0.9, 8.8), Vector3(10.0, 0.45, 0), Build.mat(Color(0.5, 0.5, 0.48), 0.6), false)
	Build.box(lot, Vector3(1.2, 0.8, 0.05), Vector3(8.0, 1.3, 4.5), Build.mat(Color(0.95, 0.95, 0.9), 0.6), false)
	var ll := Build.label(lot, "売地\n（となりの区画）", Vector3(8.0, 1.3, 4.53), 60, Color(0.7, 0.1, 0.1))
	ll.double_sided = false
	Build.cyl(lot, 0.03, 0.03, 0.9, Vector3(8.0, 0.45, 4.5), Build.mat(Color(0.4, 0.4, 0.4), 0.5))

	# となりの建物（左右）
	_building(root, Vector3(-11.1, 0, 0.0), Vector3(10.0, 7.0, 9.0), Color(0.42, 0.38, 0.34), "居酒屋")
	_building(root, Vector3(15.6, 0, 0.0), Vector3(11.0, 9.0, 9.0), Color(0.35, 0.37, 0.4), "コンビニ")
	_building(root, Vector3(-26.0, 0, 0.0), Vector3(16.0, 6.0, 9.0), Color(0.5, 0.45, 0.38), "")
	# 向かいの家並みと自宅
	_building(root, Vector3(-8.0, 0, 20.0), Vector3(14.0, 8.0, 9.0), Color(0.38, 0.36, 0.33), "", PI)
	_building(root, Vector3(10.0, 0, 20.0), Vector3(16.0, 10.0, 9.0), Color(0.32, 0.33, 0.36), "", PI)
	_building(root, Vector3(-30.5, 0, 20.0), Vector3(7.0, 6.0, 9.0), Color(0.45, 0.42, 0.36), "", PI)
	_home(root)
	# 街灯
	var pole := Build.mat(Color(0.25, 0.26, 0.28), 0.5, 0.6)
	for lx in [-28.0, -16.0, -4.0, 8.0, 20.0]:
		Build.cyl(root, 0.06, 0.08, 4.5, Vector3(lx, 2.25, 6.5), pole, true, 12)
		Build.box(root, Vector3(0.12, 0.08, 0.9), Vector3(lx, 4.45, 6.1), pole, false)
		Build.box(root, Vector3(0.3, 0.05, 0.4), Vector3(lx, 4.4, 5.7), Build.glow_mat(Color(1.0, 0.85, 0.6), 3.0), false)
		var sl := SpotLight3D.new()
		sl.position = Vector3(lx, 4.3, 5.7)
		sl.rotation.x = -PI / 2
		sl.light_color = Color(1.0, 0.85, 0.65)
		sl.light_energy = 3.0
		sl.spot_range = 8.0
		sl.spot_angle = 55.0
		root.add_child(sl)
	# 通りの端の見えない壁
	for b in [[Vector3(lw, 4, 0.2), Vector3(cx, 2, 16.6)], [Vector3(0.2, 4, 12), Vector3(x0, 2, 10.6)], [Vector3(0.2, 4, 12), Vector3(x1, 2, 10.6)], [Vector3(4.2, 4, 0.2), Vector3(8.0, 2, -4.6)], [Vector3(0.2, 4, 9.2), Vector3(10.1, 2, 0.0)]]:
		Build._add_body(root, b[1], Build._box_shape(b[0]))


static func _building(root: Node3D, pos: Vector3, size: Vector3, col: Color, sign: String, yaw: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	root.add_child(n)
	var m := Build.noise_mat(col, col.lightened(0.12), 0.4, Vector3(2, 2, 2), 0.9, randi())
	Build.box(n, size, Vector3(0, size.y / 2, 0), m)
	# 窓（夕方なので少し明かりがついている）
	var front := size.z / 2 + 0.01
	var fl := 1
	while fl * 2.8 + 1.0 < size.y:
		var wx := -size.x / 2 + 1.2
		while wx < size.x / 2 - 0.8:
			var lit := randf() < 0.45
			var wm := Build.glow_mat(Color(1.0, 0.82, 0.55), 1.2) if lit else Build.mat(Color(0.1, 0.12, 0.15), 0.2, 0.4)
			Build.box(n, Vector3(1.0, 1.1, 0.02), Vector3(wx, fl * 2.8 + 0.4, front), wm, false)
			wx += 2.0
		fl += 1
	# 1階の入口
	Build.box(n, Vector3(size.x * 0.7, 2.2, 0.02), Vector3(0, 1.1, front), Build.glow_mat(Color(0.9, 0.85, 0.7), 0.25) if sign != "" else Build.mat(Color(0.12, 0.1, 0.09), 0.5), false)
	if sign != "":
		Build.box(n, Vector3(size.x * 0.6, 0.6, 0.06), Vector3(0, 2.7, front + 0.03), Build.glow_mat(Color(0.9, 0.95, 1.0), 0.8), false)
		var l := Build.label(n, sign, Vector3(0, 2.7, front + 0.07), 120, Color(0.1, 0.15, 0.3))
		l.double_sided = false


## 自宅（向かいの小さなアパートの1階）
static func _home(root: Node3D) -> void:
	var n := Node3D.new()
	n.name = "Home"
	n.position = Vector3(-22.0, 0, 19.5)
	n.rotation.y = PI
	root.add_child(n)
	var m := Build.noise_mat(Color(0.75, 0.72, 0.64), Color(0.82, 0.79, 0.7), 0.4, Vector3(2, 2, 2), 0.9, 31)
	Build.box(n, Vector3(10.0, 5.6, 8.0), Vector3(0, 2.8, 0), m)
	Build.box(n, Vector3(10.4, 0.15, 1.4), Vector3(0, 2.85, 4.6), Build.mat(Color(0.5, 0.48, 0.44), 0.7), false)
	for i in 3:
		var dx := -3.0 + i * 3.0
		Build.box(n, Vector3(0.9, 2.0, 0.05), Vector3(dx, 1.0, 4.02), Build.mat(Color(0.3, 0.22, 0.15) if i == 1 else Color(0.35, 0.36, 0.38), 0.6), false)
		Build.box(n, Vector3(0.9, 2.0, 0.05), Vector3(dx, 3.9, 4.02), Build.mat(Color(0.35, 0.36, 0.38), 0.6), false)
	var l := Build.label(n, "コーポ焼肉通り", Vector3(0, 5.0, 4.03), 110, Color(0.25, 0.22, 0.2))
	l.double_sided = false
	var me := Build.label(n, "102 自宅", Vector3(0, 2.2, 4.06), 44, Color(0.95, 0.92, 0.85))
	me.double_sided = false
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.5, 4.8)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.0
	lamp.omni_range = 4.0
	n.add_child(lamp)
