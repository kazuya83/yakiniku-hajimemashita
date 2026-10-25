class_name OpenSign
extends Node3D
## 入口の札。Eで開店する

var _label: Label3D


func _ready() -> void:
	var wood := Build.noise_mat(Color(0.45, 0.3, 0.16), Color(0.6, 0.42, 0.24), 0.08, Vector3(1, 4, 1), 0.8, 11)
	Build.box(self, Vector3(0.5, 0.3, 0.03), Vector3.ZERO, wood)
	_label = Build.label(self, "準備中", Vector3(0, 0, 0.02), 96, Color(0.1, 0.06, 0.03))
	_label.double_sided = false


func refresh() -> void:
	_label.text = "営業中" if Game.main.phase == "open" else "準備中"
	_label.modulate = Color(0.75, 0.08, 0.05) if Game.main.phase == "open" else Color(0.1, 0.06, 0.03)


func get_hint(_p: Player) -> String:
	match Game.main.phase:
		"prep":
			if not Game.main.clocked_in:
				return "札（準備中）\nまずタイムカードを押して出社しよう"
			return "札（準備中）\nE: 札をひっくり返して開店する"
		"open":
			return "札（営業中）"
	return "札（閉店）"


func use(_p: Player) -> void:
	if Game.main.phase == "prep":
		if not Game.main.clocked_in:
			Game.say("まずタイムカードを押して出社しよう")
			return
		Game.main.open_shop()
