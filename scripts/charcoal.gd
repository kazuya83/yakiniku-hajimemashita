class_name Charcoal
extends Item
## 炭ひとかけ


func _ready() -> void:
	kind = "charcoal"
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.04, 0.045)
	mi.mesh = bm
	mi.rotation = Vector3(0.2, 0.5, 0.1)
	mi.material_override = Build.mat(Color(0.05, 0.05, 0.055), 0.95)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.06, 0.04, 0.05)
	cs.shape = b
	add_child(cs)


func rest_offset() -> float:
	return 0.02


func display_name() -> String:
	return "炭"
