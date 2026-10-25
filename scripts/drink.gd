class_name Drink
extends Item
## ジョッキ（グラス）。液と泡の量を持つ

const H := 0.15
const RIN := 0.042

var drink := ""      # "" は空のジョッキ
var level := 0.0     # 液 0〜1
var foam := 0.0      # 泡 0〜1
var empty_used := false
var _liquid: MeshInstance3D
var _foam: MeshInstance3D
var _liquid_mat: StandardMaterial3D


func _ready() -> void:
	kind = "drink"
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.92, 0.95, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	Build.cyl(self, 0.048, 0.045, H, Vector3(0, H / 2, 0), glass, false, 24)
	var handle := Build.box(self, Vector3(0.012, 0.09, 0.03), Vector3(0.062, H * 0.55, 0), glass, false)
	handle.name = "Handle"
	_liquid_mat = StandardMaterial3D.new()
	_liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_liquid_mat.roughness = 0.1
	_liquid = Build.cyl(self, RIN, RIN, 1.0, Vector3.ZERO, _liquid_mat, false, 20)
	_foam = Build.cyl(self, RIN, RIN, 1.0, Vector3.ZERO, Build.mat(Color(0.98, 0.96, 0.9), 0.9), false, 20)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.055
	cy.height = H
	cs.shape = cy
	cs.position.y = H / 2
	add_child(cs)
	refresh()


func refresh() -> void:
	if _liquid == null:
		return
	var inner := H - 0.012
	var lh := maxf(level * inner, 0.0005)
	var fh := maxf(foam * inner, 0.0005)
	_liquid.visible = level > 0.005
	_foam.visible = foam > 0.005
	_liquid.scale = Vector3(1, lh, 1)
	_liquid.position.y = 0.008 + lh / 2
	_foam.scale = Vector3(1, fh, 1)
	_foam.position.y = 0.008 + lh + fh / 2
	if drink != "":
		_liquid_mat.albedo_color = MeatData.DRINKS[drink].color


func _process(dt: float) -> void:
	# 泡は少しずつ消えて液に戻る
	if foam > 0.0 and drink == "beer":
		var d := foam * 0.004 * dt
		foam -= d
		level += d * 0.3
		refresh()


func display_name() -> String:
	if drink == "":
		return "空のジョッキ" if not empty_used else "飲み終わったジョッキ"
	return MeatData.DRINKS[drink].name


func score() -> float:
	if drink == "beer":
		var total := level + foam
		var fr := foam / maxf(total, 0.001)
		return clampf(1.0 - absf(fr - 0.28) * 2.5 - maxf(0.0, 0.88 - total) * 3.0, 0.0, 1.0)
	return clampf(1.0 - maxf(0.0, 0.85 - level) * 3.0, 0.0, 1.0)


func get_info(_p: Player) -> String:
	if drink == "":
		return ""
	var lines := [display_name()]
	if drink == "beer":
		var total := level + foam
		lines.append("液 %d%%　泡 %d%%" % [int(level * 100), int(foam * 100)])
		lines.append("泡の割合 %d%%（理想は3割）" % int(foam / maxf(total, 0.001) * 100))
	else:
		lines.append("量 %d%%（8割5分以上で満杯）" % int(level * 100))
	lines.append("出来ばえ " + Game.bar(score()))
	return "\n".join(lines)


func rest_offset() -> float:
	return 0.0
