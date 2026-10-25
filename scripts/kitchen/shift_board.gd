class_name ShiftBoard
extends Node3D
## シフト表。Eでアルバイトを雇う・辞めてもらう


func _ready() -> void:
	Build.box(self, Vector3(0.55, 0.42, 0.03), Vector3.ZERO, Build.mat(Color(0.92, 0.9, 0.82), 0.7))
	Build.box(self, Vector3(0.6, 0.47, 0.02), Vector3(0, 0, -0.012), Build.mat(Color(0.3, 0.2, 0.12), 0.6), false)
	var l := Build.label(self, "シフト表", Vector3(0, 0.14, 0.02), 44, Color(0.2, 0.12, 0.08))
	l.double_sided = false
	for i in 4:
		Build.box(self, Vector3(0.46, 0.004, 0.002), Vector3(0, 0.07 - i * 0.07, 0.017), Build.mat(Color(0.4, 0.4, 0.45), 0.8), false)


func get_hint(_p: Player) -> String:
	return "シフト表（アルバイト %d人・日給の合計 %s）\nE: アルバイトを雇う・辞めてもらう" % [Game.main.staff.size(), Game.yen(Game.main.wages())]


func use(_p: Player) -> void:
	Game.hud.open_staff()
