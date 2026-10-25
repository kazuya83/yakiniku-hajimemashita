class_name SupplyBox
extends Item
## 仕入れの段ボール（肉20枚）

var cut := "karubi"
var pieces := 20


func setup(c: String) -> SupplyBox:
	cut = c
	pieces = Game.BOX_PIECES
	return self


func _ready() -> void:
	kind = "box"
	var card := Build.noise_mat(Color(0.62, 0.46, 0.28), Color(0.7, 0.54, 0.34), 0.3, Vector3(2, 2, 2), 0.95, randi())
	Build.box(self, Vector3(0.42, 0.24, 0.3), Vector3(0, 0.12, 0), card, false)
	Build.box(self, Vector3(0.43, 0.04, 0.05), Vector3(0, 0.23, 0), Build.mat(Color(0.75, 0.68, 0.5), 0.6), false)
	var l := Build.label(self, "%s ×%d" % [MeatData.CUTS[cut].name, pieces], Vector3(0, 0.12, 0.152), 56, Color(0.15, 0.08, 0.04))
	l.double_sided = false
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.42, 0.24, 0.3)
	cs.shape = b
	cs.position.y = 0.12
	add_child(cs)


func display_name() -> String:
	return "段ボール（%s %d枚）" % [MeatData.CUTS[cut].name, pieces]


func get_hint(p: Player) -> String:
	if p.held == null:
		return display_name() + "\n左クリック: 持つ（冷蔵庫に入れる）"
	return display_name()
