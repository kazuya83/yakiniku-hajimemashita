class_name ShopBuilder
## 店内（床・壁・カウンター・厨房・テーブル・照明）を組み立てる

const W := 12.0
const D := 9.0
const H := 2.8
const DOOR_X0 := 3.9
const DOOR_X1 := 5.3


static func build(main) -> void:
	var root := Node3D.new()
	root.name = "Shop"
	main.add_child(root)
	root.add_to_group("navsrc")
	var floor_m := Build.noise_mat(Color(0.12, 0.11, 0.1), Color(0.24, 0.22, 0.2), 0.35, Vector3(0.6, 0.6, 0.6), 0.6, 1)
	var wall_m := Build.noise_mat(Color(0.66, 0.6, 0.5), Color(0.74, 0.68, 0.58), 0.6, Vector3(0.4, 0.4, 0.4), 0.95, 2)
	var wood_m := Build.noise_mat(Color(0.26, 0.15, 0.08), Color(0.42, 0.26, 0.14), 0.05, Vector3(0.3, 0.3, 3.0), 0.7, 4)
	var dark_wood := Build.noise_mat(Color(0.12, 0.07, 0.04), Color(0.22, 0.13, 0.07), 0.05, Vector3(0.3, 0.3, 3.0), 0.6, 6)
	var ceil_m := Build.mat(Color(0.1, 0.08, 0.07), 0.9)
	main.floor_mat = floor_m
	main.wall_mat = wall_m
	main.mats = {"wood": wood_m, "dark": dark_wood, "ceil": ceil_m}

	# 床・天井・壁
	Build.box(root, Vector3(W, 0.1, D), Vector3(0, -0.05, 0), floor_m)
	Build.box(root, Vector3(W, 0.1, D), Vector3(0, H + 0.05, 0), ceil_m, false)
	Build.box(root, Vector3(W, H, 0.1), Vector3(0, H / 2, -D / 2 - 0.05), wall_m)
	# 南の壁（入口 x 3.9〜5.3 があいている）
	Build.box(root, Vector3(DOOR_X0 + W / 2, H, 0.1), Vector3((DOOR_X0 - W / 2) / 2, H / 2, D / 2 + 0.05), wall_m)
	Build.box(root, Vector3(W / 2 - DOOR_X1, H, 0.1), Vector3((DOOR_X1 + W / 2) / 2, H / 2, D / 2 + 0.05), wall_m)
	Build.box(root, Vector3(DOOR_X1 - DOOR_X0, H - 2.2, 0.1), Vector3((DOOR_X0 + DOOR_X1) / 2, (H + 2.2) / 2, D / 2 + 0.05), wall_m)
	Build.box(root, Vector3(0.1, H, D), Vector3(-W / 2 - 0.05, H / 2, 0), wall_m)
	# 東の壁（隣の区画を買うと取りはらう）
	var east := Node3D.new()
	east.name = "EastWall"
	root.add_child(east)
	Build.box(east, Vector3(0.1, H, D), Vector3(W / 2 + 0.05, H / 2, 0), wall_m)
	Build.box(east, Vector3(0.03, 1.0, D), Vector3(W / 2 - 0.015, 0.5, 0), dark_wood, false)
	# 腰板
	Build.box(root, Vector3(DOOR_X0 + W / 2, 1.0, 0.03), Vector3((DOOR_X0 - W / 2) / 2, 0.5, D / 2 - 0.015), dark_wood, false)
	Build.box(root, Vector3(W / 2 - DOOR_X1, 1.0, 0.03), Vector3((DOOR_X1 + W / 2) / 2, 0.5, D / 2 - 0.015), dark_wood, false)
	Build.box(root, Vector3(0.03, 1.0, D), Vector3(-W / 2 + 0.015, 0.5, 0), dark_wood, false)
	# 天井の梁
	for x in [-4.0, -1.0, 2.0, 5.0]:
		Build.box(root, Vector3(0.18, 0.2, D), Vector3(x, H - 0.1, 0), dark_wood, false)

	_build_counter(main, root, wood_m, dark_wood)
	_build_kitchen(main, root, wood_m)
	_build_tables(main, root, wood_m, dark_wood)
	_build_entrance(main, root, dark_wood)
	_build_lights(main, root)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(W, H, D)
	probe.position = Vector3(0, H / 2, 0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	root.add_child(probe)


static func _build_counter(main, root: Node3D, wood_m: Material, dark_wood: Material) -> void:
	var x0 := -4.6
	var x1 := 1.6
	var cx := (x0 + x1) / 2
	var len := x1 - x0
	Build.box(root, Vector3(len, 0.9, 0.55), Vector3(cx, 0.45, -1.15), dark_wood)
	Build.box(root, Vector3(len + 0.1, 0.06, 0.78), Vector3(cx, 0.92, -1.12), wood_m)
	var steel := Build.mat(Color(0.75, 0.76, 0.78), 0.3, 1.0)
	var stool_m := Build.mat(Color(0.5, 0.08, 0.06), 0.5)
	for x in main.SEAT_X:
		var g := Grill.new()
		g.title = "カウンターの七輪"
		g.position = Vector3(x, 0.95, -1.28)
		root.add_child(g)
		main.grills.append(g)
		_duct(root, Vector3(x, 0.95 + 0.88, -1.28), steel)
		var s := Seat.new()
		s.position = Vector3(x, 0.95, -0.9)
		s.stool_pos = Vector3(x, 0, -0.42)
		root.add_child(s)
		main.seats.append(s)
		Build.cyl(root, 0.19, 0.19, 0.06, Vector3(x, 0.66, -0.42), stool_m, false)
		Build.cyl(root, 0.03, 0.03, 0.63, Vector3(x, 0.32, -0.42), steel, false)
		Build.cyl(root, 0.17, 0.2, 0.02, Vector3(x, 0.01, -0.42), steel, false)
		# 調理用の作業スペース（皿を置く場所）
	Build.label(root, "カウンター", Vector3(cx, 0.6, -0.865), 80, Color(0.85, 0.75, 0.55)).double_sided = false


static func _duct(root: Node3D, bottom: Vector3, steel: Material) -> void:
	var top_y := ShopBuilder.H
	var hgt := top_y - bottom.y - 0.1
	Build.cyl(root, 0.1, 0.1, hgt, Vector3(bottom.x, bottom.y + 0.1 + hgt / 2, bottom.z), steel, false, 24)
	Build.cyl(root, 0.1, 0.22, 0.14, Vector3(bottom.x, bottom.y + 0.07, bottom.z), steel, false, 32)


static func _build_kitchen(main, root: Node3D, wood_m: Material) -> void:
	var steel := Build.mat(Color(0.7, 0.71, 0.73), 0.35, 0.9)
	# 作業台（発注タブレットつき）
	var prep := Node3D.new()
	prep.name = "PrepTable"
	prep.position = Vector3(-3.3, 0, -4.1)
	root.add_child(prep)
	Build.box(prep, Vector3(2.6, 0.88, 0.7), Vector3(0, 0.44, 0), steel)
	Build.box(prep, Vector3(2.6, 0.03, 0.7), Vector3(0, 0.895, 0), Build.mat(Color(0.82, 0.83, 0.85), 0.25, 0.9))
	var cut_board := CuttingBoard.new()
	cut_board.position = Vector3(0.3, 0.91, 0.05)
	cut_board.rotation.y = 0.05
	prep.add_child(cut_board)
	var tab := OrderTablet.new()
	tab.position = Vector3(1.2, 0.91, 0.15)
	tab.rotation.y = 0.2
	prep.add_child(tab)
	placeable(prep, "作業台", Vector2(2.6, 0.7), 15000)
	var fr := Fridge.new()
	fr.position = Vector3(-5.35, 0, -4.05)
	root.add_child(fr)
	placeable(fr, "冷蔵庫", Vector2(1.0, 0.75), 60000)
	var cb := CharcoalBox.new()
	cb.position = Vector3(-1.5, 0, -4.1)
	root.add_child(cb)
	placeable(cb, "炭箱", Vector2(0.5, 0.4), 3000)
	var sk := Sink.new()
	sk.position = Vector3(-0.3, 0, -4.12)
	root.add_child(sk)
	placeable(sk, "シンク", Vector2(1.0, 0.65), 30000)
	var gr := GrateRack.new()
	gr.position = Vector3(0.75, 0, -4.15)
	root.add_child(gr)
	placeable(gr, "網置き", Vector2(0.45, 0.42), 5000)
	# 飲み物コーナー（ビールサーバー・ハイボール・ウーロン茶・ジョッキ棚）
	var dc := Node3D.new()
	dc.name = "DrinkCounter"
	dc.position = Vector3(2.6, 0, -3.15)
	root.add_child(dc)
	Build.box(dc, Vector3(0.7, 0.9, 1.7), Vector3(0, 0.45, 0), steel)
	var kinds := ["beer", "highball", "oolong"]
	for k in 3:
		var tap := DrinkTap.new()
		tap.drink = kinds[k]
		tap.position = Vector3(0.05, 0.9, -0.6 + k * 0.5)
		tap.rotation.y = -PI / 2
		dc.add_child(tap)
	var jr := JugRack.new()
	jr.position = Vector3(-0.05, 0.9, 0.65)
	dc.add_child(jr)
	placeable(dc, "ドリンク台", Vector2(0.7, 1.7), 40000)
	Build.label(root, "段ボール置き場", Vector3(3.8, 1.2, -4.44), 56, Color(0.9, 0.85, 0.75))
	var tr := Trash.new()
	tr.position = Vector3(1.5, 0, -4.15)
	root.add_child(tr)
	placeable(tr, "ゴミ箱", Vector2(0.42, 0.42), 2000)
	# 棚と調味料
	Build.box(root, Vector3(3.2, 0.03, 0.3), Vector3(-1.0, 1.65, -4.33), wood_m, false)
	for i in 10:
		var b := Build.cyl(root, 0.035, 0.035, 0.2, Vector3(-2.4 + i * 0.3, 1.77, -4.33), Build.mat(Color.from_hsv(randf(), 0.5, 0.5), 0.3), false, 16)
		b.position.y = 1.765
	Build.label(root, "仕込み・洗い場", Vector3(-1.0, 2.1, -4.44), 70, Color(0.95, 0.9, 0.8))


static func _build_tables(main, root: Node3D, wood_m: Material, dark_wood: Material) -> void:
	for tx in [-3.4, 0.4]:
		add_table(main, Vector3(tx, 0, 2.6), 0.0)
	# お品書き
	var board := Build.box(root, Vector3(0.04, 1.3, 0.9), Vector3(-5.97, 1.7, 1.2), Build.mat(Color(0.1, 0.08, 0.06), 0.8), false)
	var l := Build.label(root, menu_text(), Vector3(-5.94, 1.7, 1.2), 56, Color(0.95, 0.92, 0.85))
	l.rotation.y = PI / 2
	l.double_sided = false
	main.menu_label = l


static func menu_text() -> String:
	var menu := "おしながき\n\n"
	for c in MeatData.menu():
		menu += "%s　%d円\n" % [MeatData.CUTS[c].name, MeatData.CUTS[c].price]
	return menu


## 配置モードで動かせる設備にする（size は床に置いたときの幅×奥行き）
static func placeable(n: Node3D, nm: String, size: Vector2, price: int) -> void:
	n.add_to_group("placeable")
	n.set_meta("pl_name", nm)
	n.set_meta("pl_size", size)
	n.set_meta("pl_price", price)


static func add_table(main, pos: Vector3, yaw: float) -> DiningTable:
	var steel := Build.mat(Color(0.75, 0.76, 0.78), 0.3, 1.0)
	var t := DiningTable.new()
	t.index = main.tables.size() + 1
	t.position = pos
	t.rotation.y = yaw
	main.get_node("Shop").add_child(t)
	t.build(main.mats.wood, main.mats.dark, steel)
	main.tables.append(t)
	main.grills.append(t.grill)
	main.shadow_lights.append(t.light)
	t.light.shadow_enabled = Game.quality != "low"
	return t


static func add_plant(main, pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Plant"
	n.position = pos
	n.rotation.y = yaw
	main.get_node("Shop").add_child(n)
	Build.cyl(n, 0.2, 0.15, 0.4, Vector3(0, 0.2, 0), Build.mat(Color(0.35, 0.2, 0.12), 0.7), true)
	Build.cyl(n, 0.02, 0.025, 0.7, Vector3(0, 0.75, 0), Build.mat(Color(0.3, 0.22, 0.12), 0.8))
	var leaf := Build.mat(Color(0.12, 0.32, 0.12), 0.6)
	for i in 9:
		var a := i * 2.4
		var s := Build.sphere(n, 0.17, Vector3(cos(a) * 0.17, 0.85 + (i % 3) * 0.2, sin(a) * 0.17), leaf)
		s.scale = Vector3(1.1, 0.55, 1.1)
	placeable(n, "観葉植物", Vector2(0.45, 0.45), 4000)
	return n


## 隣の区画（東側 4m）を買って店を広げる
static func expand_east(main) -> void:
	var root: Node3D = main.get_node("Shop")
	var ext := 4.0
	var x0 := W / 2
	var x1 := W / 2 + ext
	var cx := (x0 + x1) / 2
	if root.has_node("EastWall"):
		root.get_node("EastWall").free()
	if main.has_node("Outside/EmptyLot"):
		main.get_node("Outside/EmptyLot").free()
	var wall_m: Material = main.wall_mat
	var dark: Material = main.mats.dark
	Build.box(root, Vector3(ext, 0.1, D), Vector3(cx, -0.05, 0), main.floor_mat)
	Build.box(root, Vector3(ext, 0.1, D), Vector3(cx, H + 0.05, 0), main.mats.ceil, false)
	Build.box(root, Vector3(ext, H, 0.1), Vector3(cx, H / 2, -D / 2 - 0.05), wall_m)
	Build.box(root, Vector3(ext, H, 0.1), Vector3(cx, H / 2, D / 2 + 0.05), wall_m)
	Build.box(root, Vector3(0.1, H, D), Vector3(x1 + 0.05, H / 2, 0), wall_m)
	Build.box(root, Vector3(ext, 1.0, 0.03), Vector3(cx, 0.5, D / 2 - 0.015), dark, false)
	Build.box(root, Vector3(0.03, 1.0, D), Vector3(x1 - 0.015, 0.5, 0), dark, false)
	# もとの壁のあった所に柱と梁
	for z in [-D / 2 + 0.1, D / 2 - 0.1]:
		Build.box(root, Vector3(0.2, H, 0.2), Vector3(x0, H / 2, z), dark)
	Build.box(root, Vector3(0.2, 0.25, D), Vector3(x0, H - 0.125, 0), dark, false)
	Build.box(root, Vector3(0.18, 0.2, D), Vector3(x0 + 2.5, H - 0.1, 0), dark, false)
	for p in [Vector3(cx, 2.3, -2.0), Vector3(cx, 2.3, 2.0)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.78, 0.55)
		l.light_energy = 1.3
		l.omni_range = 4.5
		l.omni_attenuation = 1.2
		root.add_child(l)
		Build.cyl(root, 0.06, 0.2, 0.14, p + Vector3(0, 0.15, 0), Build.mat(Color(0.12, 0.09, 0.07), 0.6), false, 24)
		Build.sphere(root, 0.04, p + Vector3(0, 0.08, 0), Build.glow_mat(Color(1.0, 0.75, 0.45), 4.0))
	main.room_max_x = x1


static func _build_entrance(main, root: Node3D, dark_wood: Material) -> void:
	# 入口の自動ドア（近づくと左右に開く）
	var door := AutoDoor.new()
	door.position = Vector3((DOOR_X0 + DOOR_X1) / 2, 0, D / 2 + 0.05)
	root.add_child(door)
	var tc := TimeCard.new()
	tc.position = Vector3(3.3, 1.35, 4.42)
	tc.rotation.y = PI
	root.add_child(tc)
	var sb := ShiftBoard.new()
	sb.position = Vector3(1.8, 1.4, 4.43)
	sb.rotation.y = PI
	root.add_child(sb)
	var sign := OpenSign.new()
	sign.position = Vector3(2.6, 1.35, 4.42)
	sign.rotation.y = PI
	root.add_child(sign)
	main.sign_board = sign
	# 提灯（店内）
	for x in [3.2, 5.9]:
		var lan := Build.sphere(root, 0.18, Vector3(x, 2.25, 4.2), Build.glow_mat(Color(1.0, 0.25, 0.1), 1.6))
		lan.scale = Vector3(1, 1.3, 1)


static func _build_lights(main, root: Node3D) -> void:
	var shade := Build.mat(Color(0.12, 0.09, 0.07), 0.6)
	var bulb := Build.glow_mat(Color(1.0, 0.75, 0.45), 4.0)
	var spots := [
		Vector3(-3.6, 2.2, -0.6), Vector3(-1.6, 2.2, -0.6), Vector3(0.4, 2.2, -0.6),
		Vector3(-3.3, 2.3, -3.6), Vector3(-0.3, 2.3, -3.6), Vector3(3.8, 2.3, 0.5), Vector3(4.2, 2.3, 3.4), Vector3(-1.4, 2.3, 2.6), Vector3(2.3, 2.3, -3.1), Vector3(-5.0, 2.3, -3.0),
	]
	var i := 0
	for p in spots:
		Build.cyl(root, 0.006, 0.006, H - p.y, Vector3(p.x, (H + p.y) / 2 + 0.06, p.z), shade, false, 6)
		Build.cyl(root, 0.06, 0.2, 0.14, p + Vector3(0, 0.07, 0), shade, false, 24)
		Build.sphere(root, 0.04, p, bulb)
		var l := OmniLight3D.new()
		l.position = p - Vector3(0, 0.08, 0)
		l.light_color = Color(1.0, 0.78, 0.55)
		l.light_energy = 1.6 if i < 3 else 1.2
		l.omni_range = 4.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = i < 4
		l.light_size = 0.05
		root.add_child(l)
		if l.shadow_enabled:
			main.shadow_lights.append(l)
		i += 1
