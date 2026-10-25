class_name ShopBuilder
## 店内（床・壁・カウンター・厨房・テーブル・照明）を組み立てる

const W := 12.0
const D := 9.0
const H := 2.8


static func build(main) -> void:
	var root := Node3D.new()
	root.name = "Shop"
	main.add_child(root)
	var floor_m := Build.noise_mat(Color(0.12, 0.11, 0.1), Color(0.24, 0.22, 0.2), 0.35, Vector3(0.6, 0.6, 0.6), 0.6, 1)
	var wall_m := Build.noise_mat(Color(0.66, 0.6, 0.5), Color(0.74, 0.68, 0.58), 0.6, Vector3(0.4, 0.4, 0.4), 0.95, 2)
	var wood_m := Build.noise_mat(Color(0.26, 0.15, 0.08), Color(0.42, 0.26, 0.14), 0.05, Vector3(0.3, 0.3, 3.0), 0.7, 4)
	var dark_wood := Build.noise_mat(Color(0.12, 0.07, 0.04), Color(0.22, 0.13, 0.07), 0.05, Vector3(0.3, 0.3, 3.0), 0.6, 6)
	var ceil_m := Build.mat(Color(0.1, 0.08, 0.07), 0.9)

	# 床・天井・壁
	Build.box(root, Vector3(W, 0.1, D), Vector3(0, -0.05, 0), floor_m)
	Build.box(root, Vector3(W, 0.1, D), Vector3(0, H + 0.05, 0), ceil_m, false)
	Build.box(root, Vector3(W, H, 0.1), Vector3(0, H / 2, -D / 2 - 0.05), wall_m)
	Build.box(root, Vector3(W, H, 0.1), Vector3(0, H / 2, D / 2 + 0.05), wall_m)
	Build.box(root, Vector3(0.1, H, D), Vector3(-W / 2 - 0.05, H / 2, 0), wall_m)
	Build.box(root, Vector3(0.1, H, D), Vector3(W / 2 + 0.05, H / 2, 0), wall_m)
	# 腰板
	Build.box(root, Vector3(W, 1.0, 0.03), Vector3(0, 0.5, D / 2 - 0.015), dark_wood, false)
	Build.box(root, Vector3(0.03, 1.0, D), Vector3(-W / 2 + 0.015, 0.5, 0), dark_wood, false)
	Build.box(root, Vector3(0.03, 1.0, D), Vector3(W / 2 - 0.015, 0.5, 0), dark_wood, false)
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
	# 作業台
	Build.box(root, Vector3(2.6, 0.88, 0.7), Vector3(-3.3, 0.44, -4.1), steel)
	Build.box(root, Vector3(2.6, 0.03, 0.7), Vector3(-3.3, 0.895, -4.1), Build.mat(Color(0.82, 0.83, 0.85), 0.25, 0.9))
	var cut_board := Build.box(root, Vector3(0.5, 0.025, 0.35), Vector3(-3.0, 0.92, -4.05), Build.mat(Color(0.92, 0.9, 0.84), 0.6))
	cut_board.rotation.y = 0.05
	var fr := Fridge.new()
	fr.position = Vector3(-5.35, 0, -4.05)
	root.add_child(fr)
	var cb := CharcoalBox.new()
	cb.position = Vector3(-1.5, 0, -4.1)
	root.add_child(cb)
	var sk := Sink.new()
	sk.position = Vector3(-0.3, 0, -4.12)
	root.add_child(sk)
	var gr := GrateRack.new()
	gr.position = Vector3(0.75, 0, -4.15)
	root.add_child(gr)
	var tr := Trash.new()
	tr.position = Vector3(1.5, 0, -4.15)
	root.add_child(tr)
	# 棚と調味料
	Build.box(root, Vector3(3.2, 0.03, 0.3), Vector3(-1.0, 1.65, -4.33), wood_m, false)
	for i in 10:
		var b := Build.cyl(root, 0.035, 0.035, 0.2, Vector3(-2.4 + i * 0.3, 1.77, -4.33), Build.mat(Color.from_hsv(randf(), 0.5, 0.5), 0.3), false, 16)
		b.position.y = 1.765
	Build.label(root, "仕込み・洗い場", Vector3(-1.0, 2.1, -4.44), 70, Color(0.95, 0.9, 0.8))


static func _build_tables(main, root: Node3D, wood_m: Material, dark_wood: Material) -> void:
	var steel := Build.mat(Color(0.75, 0.76, 0.78), 0.3, 1.0)
	var idx := 1
	for tx in [-3.4, 0.4]:
		var t := DiningTable.new()
		t.index = idx
		t.position = Vector3(tx, 0, 2.6)
		root.add_child(t)
		t.build(wood_m, dark_wood, steel)
		main.tables.append(t)
		main.grills.append(t.grill)
		_duct(root, Vector3(tx, 0.75 + 0.75, 2.6), steel)
		idx += 1
	# お品書き
	var menu := "おしながき\n\n"
	for c in MeatData.ORDER:
		menu += "%s　%d円\n" % [MeatData.CUTS[c].name, MeatData.CUTS[c].price]
	var board := Build.box(root, Vector3(0.04, 1.1, 0.9), Vector3(-5.97, 1.7, 1.2), Build.mat(Color(0.1, 0.08, 0.06), 0.8), false)
	var l := Build.label(root, menu, Vector3(-5.94, 1.7, 1.2), 64, Color(0.95, 0.92, 0.85))
	l.rotation.y = PI / 2
	l.double_sided = false


static func _build_entrance(main, root: Node3D, dark_wood: Material) -> void:
	# 入口の引き戸と暖簾
	Build.box(root, Vector3(1.4, 2.2, 0.06), Vector3(4.6, 1.1, 4.47), Build.mat(Color(0.2, 0.14, 0.09), 0.6), false)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.07, 0.1, 0.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	Build.box(root, Vector3(1.2, 1.4, 0.02), Vector3(4.6, 1.3, 4.43), glass, false)
	var noren := Build.mat(Color(0.12, 0.13, 0.2), 0.9)
	for i in 3:
		Build.box(root, Vector3(0.44, 0.55, 0.01), Vector3(4.15 + i * 0.45, 1.95, 4.38), noren, false)
	var nl := Build.label(root, "焼 肉", Vector3(4.6, 1.95, 4.37), 140, Color(0.95, 0.93, 0.88))
	nl.rotation.y = PI
	nl.double_sided = false
	var sign := OpenSign.new()
	sign.position = Vector3(3.55, 1.35, 4.36)
	sign.rotation.y = PI
	root.add_child(sign)
	main.sign_board = sign
	# 提灯
	for x in [3.2, 5.9]:
		var lan := Build.sphere(root, 0.18, Vector3(x, 2.25, 4.2), Build.glow_mat(Color(1.0, 0.25, 0.1), 1.6))
		lan.scale = Vector3(1, 1.3, 1)


static func _build_lights(main, root: Node3D) -> void:
	var shade := Build.mat(Color(0.12, 0.09, 0.07), 0.6)
	var bulb := Build.glow_mat(Color(1.0, 0.75, 0.45), 4.0)
	var spots := [
		Vector3(-3.6, 2.2, -0.6), Vector3(-1.6, 2.2, -0.6), Vector3(0.4, 2.2, -0.6),
		Vector3(-3.4, 2.15, 2.6), Vector3(0.4, 2.15, 2.6),
		Vector3(-3.3, 2.3, -3.6), Vector3(-0.3, 2.3, -3.6), Vector3(3.8, 2.3, 0.5), Vector3(4.2, 2.3, 3.4),
	]
	var i := 0
	for p in spots:
		Build.cyl(root, 0.006, 0.006, H - p.y, Vector3(p.x, (H + p.y) / 2 + 0.06, p.z), shade, false, 6)
		Build.cyl(root, 0.06, 0.2, 0.14, p + Vector3(0, 0.07, 0), shade, false, 24)
		Build.sphere(root, 0.04, p, bulb)
		var l := OmniLight3D.new()
		l.position = p - Vector3(0, 0.08, 0)
		l.light_color = Color(1.0, 0.78, 0.55)
		l.light_energy = 1.6 if i < 5 else 1.2
		l.omni_range = 4.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = i < 6
		l.light_size = 0.05
		root.add_child(l)
		if l.shadow_enabled:
			main.shadow_lights.append(l)
		i += 1
