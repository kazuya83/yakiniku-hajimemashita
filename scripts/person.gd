class_name Person
extends Node3D
## 人の見た目と歩き。お客さんが使う

var model: Node3D
var head: MeshInstance3D
var arm: MeshInstance3D
var path: Array[Vector3] = []
var speed := 1.3
var seated := false
var _walk_t := 0.0


func _ready() -> void:
	model = Node3D.new()
	add_child(model)
	var shirt := Build.mat(Color.from_hsv(randf(), randf_range(0.2, 0.6), randf_range(0.35, 0.8)), 0.8)
	var skin := Build.mat(Color(0.93, 0.78, 0.65).darkened(randf() * 0.25), 0.6)
	var hair := Build.mat(Color(0.06, 0.05, 0.04).lightened(randf() * 0.25), 0.7)
	var legs := Build.mat(Color.from_hsv(randf(), 0.2, randf_range(0.12, 0.3)), 0.8)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 0.75
	body.mesh = cap
	body.material_override = shirt
	body.position.y = 1.15
	model.add_child(body)
	for s in [-0.09, 0.09]:
		Build.box(model, Vector3(0.13, 0.8, 0.14), Vector3(s, 0.4, 0), legs, false)
	arm = Build.box(model, Vector3(0.09, 0.5, 0.09), Vector3(0.24, 1.15, 0), shirt, false)
	Build.box(model, Vector3(0.09, 0.5, 0.09), Vector3(-0.24, 1.15, 0), shirt, false)
	head = Build.sphere(model, 0.12, Vector3(0, 1.66, 0), skin)
	var h := Build.sphere(head, 0.125, Vector3(0, 0.035, 0.015), hair)
	h.scale = Vector3(1, 0.8, 1)


## 歩き終わったら true
func walk(dt: float) -> bool:
	if path.is_empty():
		return true
	var target: Vector3 = path[0]
	var to := target - position
	to.y = 0
	var step := speed * dt
	if to.length() <= step:
		position = Vector3(target.x, 0, target.z)
		path.pop_front()
	else:
		var d := to.normalized()
		position += d * step
		rotation.y = atan2(-d.x, -d.z)
		_walk_t += dt * 9.0
		model.position.y = absf(sin(_walk_t)) * 0.03
	return path.is_empty()


func sit(face_yaw: float, height: float = -0.2) -> void:
	seated = true
	rotation.y = face_yaw
	model.position.y = height


func stand() -> void:
	seated = false
	model.position.y = 0.0
	raise_hand(false)


func raise_hand(on: bool) -> void:
	if arm:
		arm.rotation.x = -2.6 if on else 0.0
		arm.position.y = 1.45 if on else 1.15
