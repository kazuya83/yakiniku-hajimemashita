class_name Trash
extends Node3D
## ゴミ箱


func _ready() -> void:
	Build.cyl(self, 0.2, 0.18, 0.6, Vector3(0, 0.3, 0), Build.mat(Color(0.25, 0.3, 0.28), 0.6), true)
	Build.cyl(self, 0.21, 0.21, 0.03, Vector3(0, 0.6, 0), Build.mat(Color(0.18, 0.22, 0.2), 0.5), false)


func get_hint(p: Player) -> String:
	if p.held is Meat or p.held is Plate or p.held is Charcoal or p.held is SupplyBox:
		return "ゴミ箱\n左クリック: 捨てる"
	return "ゴミ箱"


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	if p.held is Meat or p.held is Plate or p.held is Charcoal or p.held is SupplyBox:
		var it: Item = p.held
		if it is Plate:
			Game.dirty_plates += 1
			Game.say("肉を捨てて、皿は洗い物へ")
		it.detach()
		it.queue_free()
		return true
	return false
