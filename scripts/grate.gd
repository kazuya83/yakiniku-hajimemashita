class_name Grate
extends Item
## 焼き網。焼くほど汚れ、汚れると焦げつきやすくなる

const R := 0.165
var dirt := 0.0
var mat: StandardMaterial3D


func _ready() -> void:
	kind = "grate"
	mat = Build.mat(Color(0.72, 0.72, 0.74), 0.35, 1.0)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = R - 0.006
	tm.outer_radius = R
	tm.rings = 48
	rim.mesh = tm
	rim.scale = Vector3(1, 0.5, 1)
	rim.material_override = mat
	add_child(rim)
	var z := -R + 0.012
	while z < R - 0.008:
		var len := 2.0 * sqrt(R * R - z * z) - 0.006
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(len, 0.003, 0.003)
		bar.mesh = bm
		bar.position = Vector3(0, 0, z)
		bar.material_override = mat
		add_child(bar)
		z += 0.012
	for x in [-0.07, 0.07]:
		var cb := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(0.004, 0.004, 2.0 * sqrt(R * R - x * x))
		cb.mesh = cbm
		cb.position = Vector3(x, -0.003, 0)
		cb.material_override = mat
		add_child(cb)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = R
	cy.height = 0.012
	cs.shape = cy
	add_child(cs)
	_update_mat()


func add_dirt(v: float) -> void:
	dirt = clampf(dirt + v, 0.0, 1.0)
	_update_mat()


func clean(v: float) -> void:
	dirt = clampf(dirt - v, 0.0, 1.0)
	_update_mat()


func _update_mat() -> void:
	if mat:
		mat.albedo_color = Color(0.72, 0.72, 0.74).lerp(Color(0.09, 0.065, 0.05), dirt)
		mat.metallic = lerpf(1.0, 0.3, dirt)
		mat.roughness = lerpf(0.35, 0.9, dirt)


func rest_offset() -> float:
	return 0.006


func display_name() -> String:
	if dirt < 0.1:
		return "きれいな網"
	return "網（汚れ %d%%）" % int(dirt * 100)


func get_hint(p: Player) -> String:
	if container and container.has_method("get_hint") and not (container is Player):
		return container.get_hint(p)
	return super.get_hint(p)


func primary(p: Player, pos: Vector3, nrm: Vector3) -> bool:
	if container and container.has_method("primary"):
		return container.primary(p, pos, nrm)
	return super.primary(p, pos, nrm)


func get_info(p: Player) -> String:
	if container and container.has_method("get_info"):
		return container.get_info(p)
	return "網の汚れ  " + Game.bar(dirt)
