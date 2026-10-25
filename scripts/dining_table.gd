class_name DiningTable
extends Node3D
## テーブル席。お客さんのグループが座り、自分たちで肉を焼く

const SLOTS := [Vector3(-0.42, 0, -0.2), Vector3(0.42, 0, -0.2), Vector3(-0.42, 0, 0.2), Vector3(0.42, 0, 0.2), Vector3(-0.2, 0, 0.3), Vector3(0.2, 0, -0.3)]
const TOP_Y := 0.75

var index := 1
var grill: Grill
var party: TableParty = null
var plates: Array[Plate] = []
var chairs: Array[Vector3] = []
var chair_yaw: Array[float] = []


func build(wood_m: Material, dark_wood: Material, steel: Material) -> void:
	Build.box(self, Vector3(1.3, 0.06, 0.85), Vector3(0, 0.72, 0), wood_m)
	Build.box(self, Vector3(1.1, 0.69, 0.65), Vector3(0, 0.345, 0), dark_wood)
	grill = Grill.new()
	grill.title = "テーブル%dの七輪" % index
	grill.position = Vector3(0, TOP_Y, 0)
	add_child(grill)
	for dx in [-0.35, 0.35]:
		for dz in [-0.75, 0.75]:
			Build.box(self, Vector3(0.42, 0.45, 0.42), Vector3(dx, 0.225, dz), dark_wood)
			chairs.append(position + Vector3(dx, 0, dz * 0.97))
			chair_yaw.append(PI if dz < 0 else 0.0)


func is_clean() -> bool:
	return plates.is_empty()


func remove_item(n: Node) -> void:
	if n is Plate:
		plates.erase(n)


func put_plate(pl: Plate) -> bool:
	if plates.size() >= SLOTS.size():
		Game.say("テーブルに皿を置く場所がない")
		return false
	pl.detach()
	pl.reparent(self, false)
	var used := plates.map(func(x): return x.position)
	for s in SLOTS:
		var free := true
		for u in used:
			if (u - Vector3(s.x, TOP_Y, s.z)).length() < 0.05:
				free = false
		if free:
			pl.position = Vector3(s.x, TOP_Y, s.z)
			break
	pl.rotation = Vector3.ZERO
	pl.container = self
	pl.set_placed()
	plates.append(pl)
	return true


func get_hint(p: Player) -> String:
	var t := "テーブル%d" % index
	if party:
		t += "（%s）" % party.status_text()
		match party.state:
			"call_order":
				t += "\nE: 注文を聞く"
			"call_bill":
				t += "\nE: お会計"
		if party.need != "":
			t += "\n" + party.need_text()
	if p.held is Plate:
		t += "\n左クリック: 皿を出す・置く"
	elif party == null and not plates.is_empty():
		t += "\n皿を下げると次のお客さんが座れる"
	return t


func use(p: Player) -> void:
	if party:
		party.on_use(p)


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	if p.held is Plate:
		var pl: Plate = p.held
		if party and party.wants(pl):
			put_plate(pl)
			party.on_plate(pl)
		elif party and not pl.meats.is_empty():
			party.say("それは頼んでないです")
		else:
			put_plate(pl)
		return true
	return false
