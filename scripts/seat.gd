class_name Seat
extends Node3D
## カウンター席のお客さんの取り皿。焼いた肉をここに置いて出す

var customer: Customer = null
var meats: Array[Meat] = []
var stool_pos := Vector3.ZERO


func _ready() -> void:
	Build.cyl(self, 0.1, 0.075, 0.014, Vector3(0, 0.007, 0), Build.mat(Color(0.12, 0.1, 0.09), 0.3), false, 32)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.26, 0.03, 0.22)
	cs.shape = b
	cs.position.y = 0.015
	sb.add_child(cs)
	add_child(sb)


func add_meat(m: Meat) -> void:
	m.detach()
	m.reparent(self, false)
	var i := meats.size()
	m.position = Vector3((i % 2) * 0.05 - 0.025, 0.016 + m.data.t * 0.5 + i * 0.002, (i / 2) * 0.04 - 0.02)
	m.rotation = Vector3(PI if m.flipped else 0.0, randf_range(-0.5, 0.5), 0)
	m.container = self
	m.collision_layer = 0
	meats.append(m)


func remove_item(n: Node) -> void:
	if n is Meat:
		meats.erase(n)


func clear() -> void:
	for m in meats:
		m.queue_free()
	meats.clear()


func get_hint(p: Player) -> String:
	if customer == null or not customer.is_seated():
		return "カウンター席の取り皿"
	var t := "お客さんの取り皿（注文: %s）" % customer.order_text()
	if p.held is Meat or p.held is Plate:
		t += "\n左クリック: 焼いた肉を出す"
	return t


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	if customer == null or not customer.is_seated():
		return false
	if p.held is Meat:
		customer.offer([p.held])
		return true
	if p.held is Plate:
		var pl: Plate = p.held
		customer.offer(pl.meats.duplicate())
		return true
	return false
