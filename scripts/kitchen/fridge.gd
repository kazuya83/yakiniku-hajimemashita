class_name Fridge
extends Node3D
## 業務用冷蔵庫。部位を選んで、肉4枚をのせた皿で取り出す

var selected := 1


func _ready() -> void:
	var steel := Build.noise_mat(Color(0.62, 0.63, 0.65), Color(0.74, 0.75, 0.77), 0.2, Vector3(1, 8, 1), 0.35, 3)
	steel.metallic = 0.8
	Build.box(self, Vector3(1.0, 1.9, 0.7), Vector3(0, 0.95, 0), steel)
	var dark := Build.mat(Color(0.15, 0.15, 0.16), 0.5)
	Build.box(self, Vector3(0.006, 1.75, 0.01), Vector3(0, 0.95, 0.352), dark, false)
	for x in [-0.07, 0.07]:
		Build.box(self, Vector3(0.02, 0.35, 0.03), Vector3(x, 1.1, 0.37), Build.mat(Color(0.85, 0.85, 0.86), 0.25, 1.0), false)
	var l := Build.label(self, "冷蔵", Vector3(0, 1.7, 0.36), 72, Color(0.2, 0.25, 0.35))
	l.double_sided = false


func _cut() -> String:
	return MeatData.ORDER[selected]


func _cost() -> int:
	return int(MeatData.CUTS[_cut()].price * 0.35 / 10.0) * 10


func get_hint(p: Player) -> String:
	var d: Dictionary = MeatData.CUTS[_cut()]
	var t := "冷蔵庫　＜ %s ＞" % d.name
	if p.held == null:
		t += "\n左クリック / E: %s 1皿（4枚）を出す（仕入れ値 %s）" % [d.name, Game.yen(_cost())]
	else:
		t += "\n手をあけてから取り出す"
	t += "\nホイール: 部位を変える"
	return t


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	use(p)
	return true


func use(p: Player) -> void:
	if p.held:
		return
	var plate := Plate.new()
	Game.main.items_root.add_child(plate)
	for i in 4:
		var m := Meat.new().setup(_cut())
		Game.main.items_root.add_child(m)
		plate.add_meat(m)
	p.pick(plate)
	Game.add_money(-_cost())


func scroll(_p: Player, d: int) -> void:
	selected = posmod(selected + d, MeatData.ORDER.size())
