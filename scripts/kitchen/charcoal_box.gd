class_name CharcoalBox
extends Node3D
## 炭箱


func _ready() -> void:
	var wood := Build.noise_mat(Color(0.35, 0.22, 0.12), Color(0.5, 0.33, 0.18), 0.08, Vector3(1, 6, 1), 0.85, 5)
	Build.box(self, Vector3(0.5, 0.35, 0.4), Vector3(0, 0.175, 0), wood)
	var coal := Build.mat(Color(0.05, 0.05, 0.055), 0.95)
	for i in 14:
		var c := Build.box(self, Vector3(0.06, 0.04, 0.05), Vector3(randf_range(-0.18, 0.18), 0.36 + randf() * 0.02, randf_range(-0.13, 0.13)), coal, false)
		c.rotation = Vector3(randf(), randf() * TAU, randf())
	Build.label(self, "炭", Vector3(0, 0.2, 0.205), 64, Color(0.95, 0.9, 0.8))


func get_hint(p: Player) -> String:
	return "炭箱\n左クリック / E: 炭を1つ取る" if p.held == null else "炭箱"


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	use(p)
	return true


func use(p: Player) -> void:
	if p.held:
		return
	var c := Charcoal.new()
	Game.main.items_root.add_child(c)
	p.pick(c)
