class_name SaveData
## お店のセーブ（user://save.json）
## 閉店後の結果画面と、次の日の朝に自動で保存する。起動画面の「続きから」で読み込む

const PATH := "user://save.json"
const VERSION := 1


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


## 保存した日と所持金（起動画面に出す）
static func summary() -> String:
	var d := _read()
	if d.is_empty():
		return ""
	return "%d日目・所持金 %s" % [int(d.day) + (1 if d.get("morning_pending", false) else 0), Game.yen(int(d.money))]


## morning_pending: 閉店後に保存したとき true（読み込んだら次の日の朝から始める）
static func save(main, morning_pending: bool) -> void:
	var stock := {}
	for c in Game.stock:
		stock[c] = Game.stock[c].duplicate(true)
	var items := []
	var counts := {}
	for n in main.get_tree().get_nodes_in_group("placeable"):
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		var nm: String = n.get_meta("pl_name")
		var kind := "fixed"
		if n is DiningTable:
			kind = "table"
		elif n.name.begins_with("Plant"):
			kind = "plant"
		var i: int = counts.get(nm, 0)
		counts[nm] = i + 1
		# 動かし中の物は元の場所で保存する
		var pos: Vector3 = n.position
		var yaw: float = n.rotation.y
		if main.build and main.build.carrying == n:
			pos = main.build._from_pos
			yaw = main.build._from_yaw
		items.append({"kind": kind, "name": nm, "i": i, "x": pos.x, "z": pos.z, "yaw": yaw})
	var boxes := []
	for b in main.items_root.get_children():
		if b is SupplyBox and not b.is_queued_for_deletion():
			boxes.append({"cut": ("b_" if b.block else "") + b.cut, "pieces": b.pieces,
				"x": b.global_position.x, "y": b.global_position.y, "z": b.global_position.z})
	var d := {
		"version": VERSION,
		"morning_pending": morning_pending,
		"money": Game.money,
		"day": Game.day,
		"reviews": Game.reviews,
		"stock": stock,
		"orders": Game.orders,
		"clean_plates": Game.clean_plates + Game.dirty_plates,
		"clean_jugs": Game.clean_jugs + Game.dirty_jugs,
		"fame": Game.fame,
		"unlocked": Game.unlocked,
		"blocks": Game.blocks,
		"wall": main.build.wall_name,
		"floor": main.build.floor_name,
		"expanded": main.build.expanded,
		"items": items,
		"staff": main.staff.map(func(s): return s.role),
		"boxes": boxes,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("セーブできなかった: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(d, "\t"))


static func _read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## 起動直後（店が初期状態のとき）に呼ぶ。読み込めたら true
static func load_into(main) -> bool:
	var d := _read()
	if d.is_empty():
		return false
	Game.money = int(d.money)
	Game.day = int(d.day)
	Game.reviews.clear()
	for r in d.get("reviews", []):
		Game.reviews.append(float(r))
	Game.stock.clear()
	for c in d.get("stock", {}):
		var lots: Array = []
		for lot in d.stock[c]:
			lots.append({"n": int(lot.n), "exp": int(lot.exp)})
		Game.stock[c] = lots
	Game.orders.clear()
	for c in d.get("orders", {}):
		Game.orders[c] = int(d.orders[c])
	Game.clean_plates = int(d.get("clean_plates", 12))
	Game.dirty_plates = 0
	Game.clean_jugs = int(d.get("clean_jugs", 8))
	Game.dirty_jugs = 0
	Game.fame = float(d.get("fame", 0.0))
	Game.unlocked.clear()
	for k in d.get("unlocked", {}):
		Game.unlocked[k] = bool(d.unlocked[k])
	Game.blocks.clear()
	for k in d.get("blocks", {}):
		Game.blocks[k] = int(d.blocks[k])
	_load_shop(main, d)
	for role in d.get("staff", []):
		if Game.ROLES.has(role):
			main.hire(role)
	for b in d.get("boxes", []):
		var box := SupplyBox.new().setup(str(b.cut))
		main.items_root.add_child(box)
		box.pieces = int(b.pieces)
		box.global_position = Vector3(float(b.x), float(b.y), float(b.z))
	main.loaded_from_save(bool(d.get("morning_pending", false)))
	Game.money_changed.emit()
	return true


static func _load_shop(main, d: Dictionary) -> void:
	var bm = main.build
	if bm.WALLS.has(d.get("wall", "")):
		bm.wall_name = d.wall
		bm._recolor(main.wall_mat, bm.WALLS[d.wall])
	if bm.FLOORS.has(d.get("floor", "")):
		bm.floor_name = d.floor
		bm._recolor(main.floor_mat, bm.FLOORS[d.floor])
	if d.get("expanded", false) and not bm.expanded:
		bm.expanded = true
		ShopBuilder.expand_east(main)
	if Game.has("dishwasher"):
		var dw := Dishwasher.new()
		main.get_node("Shop").add_child(dw)
	if Game.has("premium"):
		main.menu_label.text = ShopBuilder.menu_text()
	# テーブルと観葉植物は作り直す
	for n in main.get_tree().get_nodes_in_group("placeable"):
		if n is DiningTable or n.name.begins_with("Plant"):
			if n is DiningTable:
				bm._remove(n)
			else:
				n.queue_free()
			n.remove_from_group("placeable")
	# 厨房などの設備は名前ごとの順番で探して動かす
	var fixed := {}
	for n in main.get_tree().get_nodes_in_group("placeable"):
		var nm: String = n.get_meta("pl_name")
		if not fixed.has(nm):
			fixed[nm] = []
		fixed[nm].append(n)
	for it in d.get("items", []):
		var pos := Vector3(float(it.x), 0, float(it.z))
		var yaw := float(it.yaw)
		match str(it.kind):
			"table":
				var t: DiningTable = ShopBuilder.add_table(main, pos, yaw)
				t.refresh_chairs()
			"plant":
				ShopBuilder.add_plant(main, pos, yaw)
			_:
				var list: Array = fixed.get(str(it.name), [])
				var i := int(it.i)
				if i < list.size():
					var n: Node3D = list[i]
					n.position = Vector3(pos.x, n.position.y, pos.z)
					n.rotation.y = yaw
	if Game.has("touch"):
		for t in main.tables:
			t.add_touch_panel()
	main.rebake()
