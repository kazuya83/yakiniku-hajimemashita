class_name Register
extends Node3D
## 入口近くのレジ。食べ終わったお客さんがここに並び、E でお会計する
## 並ぶ人（Customer / TableParty）は bill_label() / bill_total() / at_register() / pay_at_register() / move_in_line(pos) を持つ

const SPACING := 0.75

var queue: Array = []
var _screen: Label3D
var _drawer: Node3D
var _ring_t := 0.0


func _ready() -> void:
	var wood := Build.mat(Color(0.2, 0.12, 0.07), 0.6)
	# 台（お客さん側が +Z）
	Build.box(self, Vector3(0.8, 0.95, 0.55), Vector3(0, 0.475, 0), wood)
	Build.box(self, Vector3(0.86, 0.04, 0.6), Vector3(0, 0.97, 0), Build.mat(Color(0.12, 0.08, 0.05), 0.4))
	# レジ本体
	var body := Build.mat(Color(0.86, 0.85, 0.82), 0.45)
	Build.box(self, Vector3(0.42, 0.1, 0.36), Vector3(-0.08, 1.04, -0.02), body)
	_drawer = Node3D.new()
	_drawer.position = Vector3(-0.08, 1.0, 0.0)
	add_child(_drawer)
	Build.box(_drawer, Vector3(0.38, 0.05, 0.34), Vector3(0, 0, 0), Build.mat(Color(0.3, 0.3, 0.32), 0.4, 0.6), false)
	for i in 4:
		Build.box(_drawer, Vector3(0.07, 0.02, 0.12), Vector3(-0.13 + i * 0.087, 0.02, 0.05), Build.mat(Color(0.55, 0.62, 0.5) if i < 2 else Color(0.75, 0.66, 0.45), 0.7), false)
	# キー
	Build.box(self, Vector3(0.3, 0.03, 0.12), Vector3(-0.08, 1.1, 0.1), Build.mat(Color(0.25, 0.25, 0.27), 0.5), false)
	for i in 12:
		Build.box(self, Vector3(0.04, 0.012, 0.03), Vector3(-0.2 + (i % 6) * 0.048, 1.12, 0.07 + (i / 6) * 0.045), Build.mat(Color(0.92, 0.92, 0.9), 0.5), false)
	# お客さん向けの表示
	var pole := Build.box(self, Vector3(0.04, 0.22, 0.04), Vector3(-0.08, 1.2, -0.1), body, false)
	pole.name = "Pole"
	Build.box(self, Vector3(0.3, 0.12, 0.03), Vector3(-0.08, 1.34, -0.1), Build.mat(Color(0.05, 0.05, 0.06), 0.3), false)
	_screen = Build.label(self, "", Vector3(-0.08, 1.34, -0.08), 34, Color(0.45, 1.0, 0.55))
	_screen.double_sided = false
	# キャッシュトレー
	Build.box(self, Vector3(0.18, 0.01, 0.13), Vector3(0.24, 1.0, 0.16), Build.mat(Color(0.15, 0.15, 0.17), 0.3), false)
	var l := Build.label(self, "お会計", Vector3(0, 0.75, 0.28), 60, Color(0.95, 0.9, 0.75))
	l.double_sided = false
	# 天井から下がった「お会計」の札と明かり
	Build.box(self, Vector3(0.6, 0.22, 0.03), Vector3(0, 2.25, 0.1), Build.mat(Color(0.12, 0.08, 0.05), 0.6), false)
	var sl := Build.label(self, "お会計", Vector3(0, 2.25, 0.12), 56, Color(1.0, 0.9, 0.7))
	sl.double_sided = false
	for x in [-0.25, 0.25]:
		Build.box(self, Vector3(0.008, 0.45, 0.008), Vector3(x, 2.58, 0.1), Build.mat(Color(0.2, 0.2, 0.2), 0.5), false)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.9, 0.3)
	lamp.light_color = Color(1.0, 0.82, 0.6)
	lamp.light_energy = 1.2
	lamp.omni_range = 2.5
	add_child(lamp)
	ShopBuilder.placeable(self, "レジ", Vector2(0.8, 0.6), 30000)
	add_to_group("register")


## i 番目に並ぶ人の立つ位置（先頭がレジの正面）
func spot(i: int) -> Vector3:
	var b := global_transform.basis
	var p := global_position + b.z * 0.85 - b.x * SPACING * i
	return Vector3(p.x, 0, p.z)


func join(p: Node) -> Vector3:
	if not queue.has(p):
		queue.append(p)
	return spot(queue.find(p))


func leave(p: Node) -> void:
	if not queue.has(p):
		return
	queue.erase(p)
	for i in queue.size():
		if is_instance_valid(queue[i]):
			queue[i].move_in_line(spot(i))


func front() -> Node:
	while not queue.is_empty() and not is_instance_valid(queue[0]):
		queue.pop_front()
	return queue[0] if not queue.is_empty() else null


func waiting() -> bool:
	var f := front()
	return f != null and f.at_register()


func _process(dt: float) -> void:
	_ring_t = maxf(_ring_t - dt, 0.0)
	_drawer.position.z = 0.0 + (0.18 * minf(_ring_t / 0.3, 1.0) if _ring_t > 0.0 else 0.0)
	var f := front()
	if _ring_t > 0.0:
		return
	_screen.text = Game.yen(f.bill_total()) if f and f.at_register() else "いらっしゃいませ"


func get_hint(_p: Player) -> String:
	var f := front()
	if f == null:
		return "レジ\nお会計を待っているお客さんはいない"
	if not f.at_register():
		return "レジ\n%s がこちらに向かっている" % f.bill_label()
	var more := "（ほかに %d 組並んでいる）" % (queue.size() - 1) if queue.size() > 1 else ""
	return "レジ　%s\n%s のお会計 %s\nE: お会計する" % [more, f.bill_label(), Game.yen(f.bill_total())]


func use(_p: Player) -> void:
	checkout()


## お会計（店長もホール担当のアルバイトも使う）
func checkout() -> bool:
	var f := front()
	if f == null or not f.at_register():
		return false
	var total: int = f.bill_total()
	_screen.text = "%s\nありがとうございました" % Game.yen(total)
	_ring_t = 1.6
	leave(f)
	f.pay_at_register()
	return true
