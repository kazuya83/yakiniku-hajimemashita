class_name Item
extends RigidBody3D
## 手で持てる物の共通部分。置いた物は物理で転がさず、その場に固定する

var kind := ""
var container: Node = null


func _init() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 2
	collision_mask = 0


## 置いたとき、底面から原点までの高さ
func rest_offset() -> float:
	return 0.0


func set_held() -> void:
	freeze = true
	collision_layer = 0


func set_placed() -> void:
	freeze = true
	collision_layer = 2


func detach() -> void:
	if container and is_instance_valid(container) and container.has_method("remove_item"):
		container.remove_item(self)
	container = null


func display_name() -> String:
	return kind


func get_hint(p: Player) -> String:
	if p.held == null:
		return display_name() + "\n左クリック: 持つ"
	return display_name()


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	if p.held == null:
		p.pick(self)
		return true
	if container and container.has_method("primary"):
		return container.primary(p, _pos, _nrm)
	return false
