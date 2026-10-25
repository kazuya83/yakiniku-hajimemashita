class_name TimeCard
extends Node3D
## 入口のタイムカード。Eで出社（その日の仕事が始まる）


func _ready() -> void:
	Build.box(self, Vector3(0.26, 0.34, 0.12), Vector3.ZERO, Build.mat(Color(0.82, 0.8, 0.74), 0.5))
	Build.box(self, Vector3(0.16, 0.06, 0.005), Vector3(0, 0.07, 0.062), Build.glow_mat(Color(0.4, 1.0, 0.6), 0.5), false)
	Build.box(self, Vector3(0.1, 0.012, 0.03), Vector3(0, -0.06, 0.06), Build.mat(Color(0.2, 0.2, 0.2), 0.4), false)
	var l := Build.label(self, "タイムカード", Vector3(0, 0.22, 0.0), 40, Color(0.95, 0.92, 0.85))
	l.double_sided = false
	# 横のカード差し
	for i in 5:
		Build.box(self, Vector3(0.07, 0.11, 0.004), Vector3(0.2 + (i % 2) * 0.0, 0.12 - i * 0.06, 0.04), Build.mat(Color(0.95, 0.93, 0.85), 0.8), false)


func get_hint(_p: Player) -> String:
	if Game.main.clocked_in:
		return "タイムカード（%s 出社済み）" % Game.main.clock_in_text()
	return "タイムカード\nE: カードを押して出社する"


func use(_p: Player) -> void:
	Game.main.clock_in()
