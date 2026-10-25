class_name Plate
extends Item
## 肉をのせる皿

const SLOTS := [Vector2(-0.04, -0.03), Vector2(0.04, -0.03), Vector2(-0.04, 0.035), Vector2(0.04, 0.035), Vector2(0.0, 0.0), Vector2(0.0, -0.06)]
var meats: Array[Meat] = []


func _ready() -> void:
	kind = "plate"
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.085
	cm.height = 0.018
	cm.radial_segments = 40
	mi.mesh = cm
	mi.position.y = 0.009
	mi.material_override = Build.mat(Color(0.93, 0.92, 0.88), 0.25)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.12
	cy.height = 0.03
	cs.shape = cy
	cs.position.y = 0.015
	add_child(cs)


func display_name() -> String:
	return "皿（%d枚）" % meats.size()


func add_meat(m: Meat) -> bool:
	if meats.size() >= SLOTS.size():
		return false
	m.detach()
	m.reparent(self, false)
	var s: Vector2 = SLOTS[meats.size()]
	m.position = Vector3(s.x, 0.019 + m.data.t * 0.5 + meats.size() * 0.002, s.y)
	m.rotation = Vector3(PI if m.flipped else 0.0, randf_range(-0.4, 0.4), 0.0)
	m.container = self
	meats.append(m)
	_apply_layer(m)
	return true


func remove_item(m: Node) -> void:
	meats.erase(m)


func _apply_layer(m: Meat) -> void:
	m.collision_layer = collision_layer


func set_held() -> void:
	super.set_held()
	for m in meats:
		_apply_layer(m)


func set_placed() -> void:
	super.set_placed()
	for m in meats:
		_apply_layer(m)


func get_hint(p: Player) -> String:
	var t := display_name()
	if p.held is Meat:
		t += "\n左クリック: 肉をのせる"
	elif p.held == null:
		t += "\n左クリック: 皿を持つ"
	return t


func primary(p: Player, pos: Vector3, nrm: Vector3) -> bool:
	if p.held is Meat:
		if not add_meat(p.held):
			Game.say("皿がいっぱい")
		return true
	return super.primary(p, pos, nrm)
