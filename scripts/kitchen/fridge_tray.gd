class_name FridgeTray
extends Node3D
## 冷蔵庫の中のトレー（部位ごと）。在庫の枚数に合わせて肉が並ぶ

const SHADER := preload("res://shaders/meat.gdshader")

var cut := "karubi"
var fridge: Fridge
var _slices: Array[MeshInstance3D] = []
var _label: Label3D
var _body: StaticBody3D


func _ready() -> void:
	Build.box(self, Vector3(0.38, 0.025, 0.42), Vector3(0, 0.0125, 0), Build.mat(Color(0.12, 0.12, 0.13), 0.4), false)
	var d: Dictionary = MeatData.CUTS[cut]
	for i in 8:
		var mi := MeshInstance3D.new()
		mi.mesh = MeatData.build_mesh(d, randf() * 100.0, cut)
		mi.material_override = MeatData.make_material(cut, randf() * 100.0)
		mi.position = Vector3(-0.09 + (i % 2) * 0.18, 0.03 + (i / 4) * 0.012, -0.13 + ((i / 2) % 2) * 0.12 + (i / 4) * 0.13)
		mi.rotation.y = randf_range(-0.3, 0.3)
		add_child(mi)
		_slices.append(mi)
	_label = Build.label(self, "", Vector3(0, 0.012, 0.215), 26, Color(0.95, 0.95, 0.95))
	_label.double_sided = false
	_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.38, 0.12, 0.42)
	cs.shape = b
	cs.position.y = 0.05
	_body.add_child(cs)
	add_child(_body)


func _process(_dt: float) -> void:
	visible = MeatData.on_menu(cut)
	if not visible:
		_body.collision_layer = 0
		return
	var n := Game.stock_count(cut)
	var show := ceili(n / 4.0)
	for i in _slices.size():
		_slices[i].visible = i < show
	_label.text = "%s %d枚" % [MeatData.CUTS[cut].name, n]
	_body.collision_layer = 1 if fridge.is_open else 0


func get_hint(p: Player) -> String:
	var n := Game.stock_count(cut)
	var left := Game.stock_days_left(cut)
	var t := "%s（在庫 %d枚%s）" % [MeatData.CUTS[cut].name, n, ("・期限まであと%d日" % left) if n > 0 else ""]
	if p.held == null:
		t += "\n左クリック: 1皿（4枚）取り出す"
	elif p.held is SupplyBox:
		return fridge.get_hint(p)
	return t


func get_info(p: Player) -> String:
	return fridge.get_info(p)


func primary(p: Player, pos: Vector3, nrm: Vector3) -> bool:
	if p.held is SupplyBox:
		return fridge.primary(p, pos, nrm)
	fridge.take(cut, p)
	return true
