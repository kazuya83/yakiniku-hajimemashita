class_name Build
## 形を作るための小さな道具


static func mat(color: Color, rough: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color * 0.3
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func noise_mat(c1: Color, c2: Color, freq: float, uv: Vector3, rough: float = 0.75, seed: int = 0) -> StandardMaterial3D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.frequency = freq
	n.seed = seed
	n.fractal_octaves = 4
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	t.color_ramp = g
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.uv1_scale = uv
	m.uv1_triplanar = true
	m.roughness = rough
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, m: Material, collide: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		_add_body(parent, pos, _box_shape(size))
	return mi


static func cyl(parent: Node, top_r: float, bot_r: float, h: float, pos: Vector3, m: Material, collide: bool = false, seg: int = 32) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var cs := CylinderShape3D.new()
		cs.radius = maxf(top_r, bot_r)
		cs.height = h
		_add_body(parent, pos, cs)
	return mi


static func sphere(parent: Node, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label(parent: Node, text: String, pos: Vector3, size: int = 64, color: Color = Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Game.font
	l.font_size = size
	l.pixel_size = 0.0025
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	parent.add_child(l)
	return l


static func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


static func _add_body(parent: Node, pos: Vector3, shape: Shape3D) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.position = pos
	var cs := CollisionShape3D.new()
	cs.shape = shape
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


static func soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t
