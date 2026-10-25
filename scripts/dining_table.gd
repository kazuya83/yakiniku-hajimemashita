class_name DiningTable
extends Node3D
## テーブル席。お客さんのグループが座り、自分たちで肉を焼く

const SLOTS := [Vector3(-0.42, 0, -0.2), Vector3(0.42, 0, -0.2), Vector3(-0.42, 0, 0.2), Vector3(0.42, 0, 0.2), Vector3(-0.2, 0, 0.3), Vector3(0.2, 0, -0.3)]
const TOP_Y := 0.75

var index := 1
var grill: Grill
var party: TableParty = null
var items: Array[Item] = []
var dirty := false
var _wipe := 0.0
var _stain: MeshInstance3D
var chairs: Array[Vector3] = []
var chair_yaw: Array[float] = []
var light: OmniLight3D


func build(wood_m: Material, dark_wood: Material, steel: Material) -> void:
	Build.box(self, Vector3(1.3, 0.06, 0.85), Vector3(0, 0.72, 0), wood_m)
	Build.box(self, Vector3(1.1, 0.69, 0.65), Vector3(0, 0.345, 0), dark_wood)
	grill = Grill.new()
	grill.title = "テーブル%dの七輪" % index
	grill.position = Vector3(0, TOP_Y, 0)
	add_child(grill)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.08, 0.05, 0.02, 0.55)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.roughness = 0.2
	_stain = Build.box(self, Vector3(1.0, 0.002, 0.6), Vector3(0, 0.752, 0), sm, false)
	_stain.visible = false
	for dx in [-0.35, 0.35]:
		for dz in [-0.75, 0.75]:
			Build.box(self, Vector3(0.42, 0.45, 0.42), Vector3(dx, 0.225, dz), dark_wood)
	ShopBuilder._duct(self, Vector3(0, TOP_Y + 0.75, 0), steel)
	# テーブルの真上の照明（テーブルと一緒に動く）
	var shade := Build.mat(Color(0.12, 0.09, 0.07), 0.6)
	var ly := 2.15
	Build.cyl(self, 0.06, 0.2, 0.14, Vector3(0.45, ly + 0.07, 0), shade, false, 24)
	Build.sphere(self, 0.04, Vector3(0.45, ly, 0), Build.glow_mat(Color(1.0, 0.75, 0.45), 4.0))
	Build.cyl(self, 0.006, 0.006, ShopBuilder.H - ly, Vector3(0.45, (ShopBuilder.H + ly) / 2 + 0.06, 0), shade, false, 6)
	light = OmniLight3D.new()
	light.position = Vector3(0.45, ly - 0.08, 0)
	light.light_color = Color(1.0, 0.78, 0.55)
	light.light_energy = 1.6
	light.omni_range = 4.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	light.light_size = 0.05
	add_child(light)
	add_to_group("placeable")
	set_meta("pl_name", "テーブル席")
	set_meta("pl_size", Vector2(1.5, 2.3))
	set_meta("pl_price", 25000)
	refresh_chairs()
	if Game.has("touch"):
		add_touch_panel()


## 椅子の位置（店内の座標）。テーブルを動かしたら呼ぶ
func refresh_chairs() -> void:
	chairs.clear()
	chair_yaw.clear()
	for dx in [-0.35, 0.35]:
		for dz in [-0.75, 0.75]:
			var lp := Vector3(dx, 0, dz * 0.97)
			chairs.append(global_transform * lp if is_inside_tree() else position + lp.rotated(Vector3.UP, rotation.y))
			chair_yaw.append((PI if dz < 0 else 0.0) + rotation.y)


## 椅子に向かうときに、いったん立つ場所（椅子の外側）
func chair_approach(i: int) -> Vector3:
	var c := chairs[i]
	var out := c - global_position
	out.y = 0
	return c + out.normalized() * 0.55


func can_move() -> bool:
	return party == null and items.is_empty()


func is_clean() -> bool:
	return items.is_empty() and not dirty


func set_dirty() -> void:
	dirty = true
	_wipe = 0.0
	_stain.visible = true


func remove_item(n: Node) -> void:
	if n is Item:
		items.erase(n)


func hold_use(p: Player, dt: float) -> void:
	if party or not dirty or not items.is_empty() or p.held != null:
		return
	_wipe += dt
	(_stain.material_override as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - _wipe / 2.5)
	if _wipe >= 2.5:
		dirty = false
		_stain.visible = false
		(_stain.material_override as StandardMaterial3D).albedo_color.a = 0.55
		Game.say("テーブルがきれいになった")


## アルバイトが片づける：皿とジョッキを洗い物にして下げる
func clear_all() -> void:
	for it in items.duplicate():
		if it is Plate:
			for m in it.meats:
				m.queue_free()
			it.meats.clear()
			Game.dirty_plates += 1
		elif it is Drink:
			Game.dirty_jugs += 1
		it.detach()
		it.queue_free()
	items.clear()


func finish_wipe() -> void:
	dirty = false
	_stain.visible = false


## タッチパネル（成長で解放）を卓に置く
func add_touch_panel() -> void:
	if has_node("Touch"):
		return
	var n := Node3D.new()
	n.name = "Touch"
	n.position = Vector3(0.55, TOP_Y, -0.33)
	n.rotation = Vector3(-0.5, PI + 0.3, 0)
	add_child(n)
	Build.box(n, Vector3(0.2, 0.14, 0.012), Vector3(0, 0.07, 0), Build.mat(Color(0.05, 0.05, 0.06), 0.3), false)
	Build.box(n, Vector3(0.18, 0.12, 0.002), Vector3(0, 0.07, -0.007), Build.glow_mat(Color(0.3, 0.6, 1.0), 0.8), false)


func put_plate(pl: Item) -> bool:
	if items.size() >= 16:
		Game.say("テーブルに置く場所がない")
		return false
	pl.detach()
	pl.reparent(self, false)
	var used := items.map(func(x): return x.position)
	var slots: Array = SLOTS if pl is Plate else [Vector3(-0.58, 0, 0.0), Vector3(0.58, 0, 0.0), Vector3(-0.58, 0, -0.3), Vector3(0.58, 0, 0.3), Vector3(-0.58, 0, 0.3), Vector3(0.58, 0, -0.3)]
	pl.position = Vector3(randf_range(-0.5, 0.5), TOP_Y, randf_range(-0.3, 0.3))
	for s in slots:
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
	items.append(pl)
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
	if p.held is Plate or p.held is Drink:
		t += "\n左クリック: 出す・置く"
	elif party == null and not items.is_empty():
		t += "\n皿とジョッキを下げると次のお客さんが座れる"
	elif party == null and dirty and p.held == null:
		t += "\nE長押し: テーブルを拭く"
	elif party == null and dirty:
		t += "\nテーブルが汚れている（手をあけてE長押しで拭く）"
	return t


func use(p: Player) -> void:
	if party:
		party.on_use(p)


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	if p.held is Plate or p.held is Drink:
		var pl: Item = p.held
		if party and party.wants(pl):
			if put_plate(pl):
				party.on_item(pl)
		elif party and ((pl is Plate and not pl.meats.is_empty()) or (pl is Drink and pl.drink != "")):
			party.say("それは頼んでないです")
		else:
			put_plate(pl)
		return true
	return false
