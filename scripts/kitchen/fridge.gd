class_name Fridge
extends Node3D
## 業務用冷蔵庫。扉を開けて、中の棚から部位を選んで1皿（4枚）ずつ取り出す

const TRAY_POS := {
	"tan": Vector3(-0.22, 1.33, 0.0), "karubi": Vector3(0.22, 1.33, 0.0),
	"rosu": Vector3(-0.22, 0.93, 0.0), "harami": Vector3(0.22, 0.93, 0.0),
}

var is_open := false
var _doors: Array[Node3D] = []
var _light: OmniLight3D
var _tw: Tween


func _ready() -> void:
	var steel := Build.noise_mat(Color(0.62, 0.63, 0.65), Color(0.74, 0.75, 0.77), 0.2, Vector3(1, 8, 1), 0.35, 3)
	steel.metallic = 0.8
	var inner := Build.mat(Color(0.88, 0.9, 0.92), 0.4, 0.2)
	# 箱（前があいている）
	Build.box(self, Vector3(1.0, 1.9, 0.04), Vector3(0, 0.95, -0.33), steel)
	Build.box(self, Vector3(0.04, 1.9, 0.7), Vector3(-0.48, 0.95, 0), steel)
	Build.box(self, Vector3(0.04, 1.9, 0.7), Vector3(0.48, 0.95, 0), steel)
	Build.box(self, Vector3(1.0, 0.06, 0.7), Vector3(0, 1.87, 0), steel)
	Build.box(self, Vector3(1.0, 0.5, 0.7), Vector3(0, 0.25, 0), steel)
	Build.box(self, Vector3(0.92, 1.3, 0.01), Vector3(0, 1.15, -0.305), inner, false)
	for y in [0.5, 0.9, 1.3]:
		Build.box(self, Vector3(0.92, 0.02, 0.6), Vector3(0, y, 0), Build.mat(Color(0.8, 0.82, 0.85), 0.3, 0.6), false)
	# 中の棚のトレー
	for c in TRAY_POS:
		var t := FridgeTray.new()
		t.cut = c
		t.fridge = self
		t.position = TRAY_POS[c]
		add_child(t)
	# 下の段は飲み物の箱（飾り）
	for i in 4:
		Build.box(self, Vector3(0.18, 0.28, 0.3), Vector3(-0.3 + i * 0.2, 0.67, 0.0), Build.mat(Color.from_hsv(0.08 + i * 0.15, 0.5, 0.6), 0.8), false)
	# 扉（左右）
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.5, 0, 0.35)
		add_child(pivot)
		var dm := Build.box(pivot, Vector3(0.49, 1.36, 0.04), Vector3(-side * 0.25, 1.17, 0.0), steel)
		Build.box(pivot, Vector3(0.02, 0.35, 0.03), Vector3(-side * 0.44, 1.2, 0.035), Build.mat(Color(0.85, 0.85, 0.86), 0.25, 1.0), false)
		if side < 0:
			var l := Build.label(pivot, "冷蔵", Vector3(-side * 0.25, 1.65, 0.025), 64, Color(0.2, 0.25, 0.35))
			l.double_sided = false
		dm.name = "Door"
		_doors.append(pivot)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.85, 0.92, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = 1.2
	_light.position = Vector3(0, 1.5, 0.1)
	add_child(_light)


func _process(_dt: float) -> void:
	if is_open and Game.main.player.global_position.distance_to(global_position) > 3.2:
		close()


func open() -> void:
	if is_open:
		return
	is_open = true
	_swing(1.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_swing(0.0)


func _swing(k: float) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(_doors[0], "rotation:y", -1.9 * k, 0.45)
	_tw.tween_property(_doors[1], "rotation:y", 1.9 * k, 0.45)
	_tw.tween_property(_light, "light_energy", 0.8 * k, 0.3)


func get_hint(p: Player) -> String:
	if p.held is SupplyBox:
		return "冷蔵庫\n左クリック: 段ボールの肉をしまう"
	if not is_open:
		return "冷蔵庫\n左クリック / E: 扉を開ける"
	return "冷蔵庫（開いている）\n中のトレーをクリックして肉を取り出す\n左クリック / E: 扉を閉める"


func get_info(_p: Player) -> String:
	var lines := ["冷蔵庫の在庫"]
	for c in MeatData.ORDER:
		var n := Game.stock_count(c)
		var left := Game.stock_days_left(c)
		lines.append("%s  %d枚%s" % [MeatData.CUTS[c].name, n, ("（期限まであと%d日）" % left) if n > 0 else ""])
	lines.append("きれいな皿  %d枚" % Game.clean_plates)
	return "\n".join(lines)


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	if p.held is SupplyBox:
		var b: SupplyBox = p.held
		Game.add_stock(b.cut, b.pieces)
		Game.say("%s %d枚を冷蔵庫にしまった" % [MeatData.CUTS[b.cut].name, b.pieces])
		b.detach()
		b.queue_free()
		return true
	use(p)
	return true


func use(_p: Player) -> void:
	if is_open:
		close()
	else:
		open()


## 1皿（4枚）を取り出して手に持つ
func take(cut: String, p: Player) -> bool:
	if p.held:
		Game.say("手をあけてから取り出そう")
		return false
	if Game.clean_plates <= 0:
		Game.say("きれいな皿がない！シンクで洗おう")
		return false
	if not Game.take_stock(cut, 4):
		Game.say("%sの在庫が足りない！タブレットで発注しよう" % MeatData.CUTS[cut].name)
		return false
	Game.clean_plates -= 1
	var plate := Plate.new()
	Game.main.items_root.add_child(plate)
	for i in 4:
		var m := Meat.new().setup(cut)
		Game.main.items_root.add_child(m)
		plate.add_meat(m)
	p.pick(plate)
	return true
