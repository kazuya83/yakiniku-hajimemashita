class_name AutoDoor
extends Node3D
## 入口の引き戸（自動ドア）。人が近づくと左右に開く

const WIDTH := 1.4
var _leaves: Array[Node3D] = []
var _open := 0.0


func _ready() -> void:
	var frame := Build.mat(Color(0.2, 0.14, 0.09), 0.6)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.25, 0.3, 0.35, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.3
	for side in [-1.0, 1.0]:
		var leaf := Node3D.new()
		add_child(leaf)
		var w := WIDTH / 2
		Build.box(leaf, Vector3(w, 0.06, 0.05), Vector3(0, 2.17, 0), frame, false)
		Build.box(leaf, Vector3(w, 0.1, 0.05), Vector3(0, 0.05, 0), frame, false)
		Build.box(leaf, Vector3(0.05, 2.2, 0.05), Vector3(-w / 2 + 0.025, 1.1, 0), frame, false)
		Build.box(leaf, Vector3(0.05, 2.2, 0.05), Vector3(w / 2 - 0.025, 1.1, 0), frame, false)
		Build.box(leaf, Vector3(w - 0.1, 2.04, 0.012), Vector3(0, 1.12, 0), glass, false)
		leaf.set_meta("side", side)
		_leaves.append(leaf)
	# 敷居
	Build.box(self, Vector3(WIDTH + 0.1, 0.02, 0.2), Vector3(0, 0.01, 0), Build.mat(Color(0.3, 0.3, 0.3), 0.5), false)


func _process(dt: float) -> void:
	var near := false
	var gp := global_position
	var pl: Node3D = Game.main.player
	if pl and Vector2(pl.global_position.x - gp.x, pl.global_position.z - gp.z).length() < 2.2:
		near = true
	if not near:
		for c in Game.main._customers:
			if is_instance_valid(c) and c._person and c._person.global_position.distance_to(gp) < 2.0:
				near = true
				break
	if not near:
		for pt in Game.main._parties:
			if is_instance_valid(pt) and pt.state in ["walk_in", "leave"]:
				for m in pt.members:
					if m.global_position.distance_to(gp) < 2.0:
						near = true
	_open = move_toward(_open, 1.0 if near else 0.0, dt * 2.5)
	for leaf in _leaves:
		var side: float = leaf.get_meta("side")
		leaf.position.x = side * (WIDTH / 4 + _open * WIDTH * 0.45)
		leaf.position.z = 0.03 * side
