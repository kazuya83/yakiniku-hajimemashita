class_name BuildMode
extends Node
## お店づくり：B で配置モード。設備を動かす・回す・買う・売る、壁紙と床、隣の区画

const GRID := 0.25
const WALLS := {
	"しっくい": [Color(0.66, 0.6, 0.5), Color(0.74, 0.68, 0.58)],
	"赤レンガ風": [Color(0.42, 0.16, 0.1), Color(0.55, 0.24, 0.15)],
	"墨色": [Color(0.13, 0.12, 0.12), Color(0.22, 0.2, 0.19)],
	"若竹": [Color(0.5, 0.56, 0.4), Color(0.62, 0.66, 0.5)],
}
const FLOORS := {
	"コンクリート": [Color(0.12, 0.11, 0.1), Color(0.24, 0.22, 0.2)],
	"木の床": [Color(0.28, 0.17, 0.09), Color(0.42, 0.27, 0.15)],
	"黒タイル": [Color(0.05, 0.05, 0.05), Color(0.13, 0.13, 0.14)],
	"畳風": [Color(0.5, 0.48, 0.3), Color(0.62, 0.6, 0.38)],
}
const WALL_PRICE := 8000
const FLOOR_PRICE := 10000
const EXPAND_PRICE := 120000

var active := false
var carrying: Node3D = null
var _from_pos := Vector3.ZERO
var _from_yaw := 0.0
var _bought := 0      # 買ったばかりで、まだ置いていない物の値段
var _valid := false
var _look: Node3D = null
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _panel: PanelContainer
var _shop: PanelContainer
var _shop_money: Label
var _expand_btn: Button
var wall_name := "しっくい"
var floor_name := "コンクリート"
var expanded := false
var _up_btns := {}


func _ready() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.35)
	_ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 0.04, 1)
	_ghost.mesh = bm
	_ghost.material_override = _ghost_mat
	_ghost.visible = false
	Game.main.add_child.call_deferred(_ghost)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	Hud.place(_panel, Vector2(-330, 16))
	_panel.custom_minimum_size = Vector2(660, 0)
	_panel.add_theme_stylebox_override("panel", Game.hud._box(Color(0.1, 0.2, 0.14, 0.9)))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	var l := Label.new()
	l.name = "L"
	l.add_theme_font_size_override("font_size", 19)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(l)
	_panel.visible = false
	_build_shop(root)


func _build_shop(root: Control) -> void:
	_shop = PanelContainer.new()
	_shop.set_anchors_preset(Control.PRESET_CENTER)
	Hud.place(_shop, Vector2(-420, -420))
	_shop.custom_minimum_size = Vector2(840, 0)
	_shop.add_theme_stylebox_override("panel", Game.hud._box(Color(0.1, 0.12, 0.16, 0.96)))
	root.add_child(_shop)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_shop.add_child(v)
	var t := Label.new()
	t.text = "お店づくりのカタログ"
	t.add_theme_font_size_override("font_size", 26)
	v.add_child(t)
	_shop_money = Label.new()
	_shop_money.add_theme_font_size_override("font_size", 19)
	v.add_child(_shop_money)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	v.add_child(hb)
	var bt: Button = Game.hud._button("テーブル席（4人がけ・七輪つき）%s" % Game.yen(25000), func(): buy("table"))
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(bt)
	var bp: Button = Game.hud._button("観葉植物 %s" % Game.yen(4000), func(): buy("plant"))
	hb.add_child(bp)
	v.add_child(_section("壁紙（%s）" % Game.yen(WALL_PRICE)))
	var hw := HBoxContainer.new()
	v.add_child(hw)
	for k in WALLS:
		var b: Button = Game.hud._button(k, func(): set_wall(k))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hw.add_child(b)
	v.add_child(_section("床（%s）" % Game.yen(FLOOR_PRICE)))
	var hf := HBoxContainer.new()
	v.add_child(hf)
	for k in FLOORS:
		var b: Button = Game.hud._button(k, func(): set_floor(k))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hf.add_child(b)
	v.add_child(_section("広げる"))
	_expand_btn = Game.hud._button("隣の区画を買って東へ4m広げる %s" % Game.yen(EXPAND_PRICE), func(): expand())
	v.add_child(_expand_btn)
	v.add_child(_section("成長（店の格が上がると買える）"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for k in Game.UPGRADES:
		var b: Button = Game.hud._button("", func(): buy_upgrade(k))
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 54)
		grid.add_child(b)
		_up_btns[k] = b
	var note := Label.new()
	note.text = "2階席は次のアップデートで追加予定"
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	v.add_child(note)
	v.add_child(Game.hud._button("閉じる", func(): close_shop()))
	_shop.visible = false


func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	return l


func shop_open() -> bool:
	return _shop.visible


func open_shop() -> void:
	_shop_money.text = "所持金 %s　　（買った設備は手に持った状態になるので、置きたい所でクリック）" % Game.yen(Game.money)
	_expand_btn.disabled = expanded
	if expanded:
		_expand_btn.text = "隣の区画は購入ずみ"
	for k in _up_btns:
		var u: Dictionary = Game.UPGRADES[k]
		var b: Button = _up_btns[k]
		if Game.has(k):
			b.text = "%s　購入ずみ" % u.name
			b.disabled = true
		elif Game.level() < u.lv:
			b.text = "%s　（店の格 Lv%d で解放）\n%s" % [u.name, u.lv, u.desc]
			b.disabled = true
		else:
			b.text = "%s　%s\n%s" % [u.name, Game.yen(u.price), u.desc]
			b.disabled = false
	_shop.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## 成長要素を買う
func buy_upgrade(k: String) -> bool:
	var u: Dictionary = Game.UPGRADES[k]
	if Game.has(k) or Game.level() < u.lv:
		return false
	if Game.money < u.price:
		Game.say("お金が足りない（%s 必要）" % Game.yen(u.price))
		return false
	if k == "dishwasher" and carrying:
		return false
	Game.add_money(-u.price)
	Game.unlocked[k] = true
	var m = Game.main
	match k:
		"touch":
			for t in m.tables:
				t.add_touch_panel()
		"dishwasher":
			var dw := Dishwasher.new()
			var p: Player = m.player
			var at: Vector3 = p.global_position - p.global_transform.basis.z * 1.5
			dw.position = Vector3(at.x, 0, at.z)
			m.get_node("Shop").add_child(dw)
			close_shop()
			carrying = dw
			_bought = 0
			_from_pos = dw.position
			Game.say("食洗機が届いた。置きたい所で左クリック")
			return true
		"premium":
			m.menu_label.text = ShopBuilder.menu_text()
	Game.say("「%s」を手に入れた！" % u.name)
	open_shop()
	return true


func close_shop() -> void:
	_shop.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle() -> void:
	if active:
		if carrying:
			cancel()
		active = false
		_panel.visible = false
		_ghost.visible = false
		close_shop()
		Game.main.rebake()
		Game.say("お店づくりを終えた")
		return
	if Game.main.phase == "open" or Game.main.phase == "closing":
		Game.say("営業中は模様替えできない（開店前か閉店後に B）")
		return
	if Game.main.player.held:
		Game.say("手に持っている物を置いてから")
		return
	active = true
	_panel.visible = true


func _unhandled_input(e: InputEvent) -> void:
	if get_tree().paused:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k == KEY_B:
			toggle()
		elif not active:
			return
		elif k == KEY_R and carrying:
			carrying.rotation.y = wrapf(carrying.rotation.y + PI / 2, -PI, PI)
		elif k == KEY_T and not carrying:
			if _shop.visible:
				close_shop()
			else:
				open_shop()
		elif k == KEY_X and carrying:
			sell()


## プレイヤーのクリックを横取りする（配置モード中）
func click(button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		if carrying:
			place()
		elif _look:
			pick(_look)
	elif button == MOUSE_BUTTON_RIGHT and carrying:
		cancel()
	elif button == MOUSE_BUTTON_WHEEL_UP and carrying:
		carrying.rotation.y = wrapf(carrying.rotation.y + PI / 2, -PI, PI)
	elif button == MOUSE_BUTTON_WHEEL_DOWN and carrying:
		carrying.rotation.y = wrapf(carrying.rotation.y - PI / 2, -PI, PI)


func pick(n: Node3D) -> void:
	if n is DiningTable and not n.can_move():
		Game.say("お客さんや皿が残っているテーブルは動かせない")
		return
	if n is Fridge and n.is_open:
		n.close()
	carrying = n
	_from_pos = n.position
	_from_yaw = n.rotation.y
	_bought = 0


func cancel() -> void:
	if not carrying:
		return
	if _bought > 0:
		Game.add_money(_bought)
		_remove(carrying)
		Game.say("買うのをやめた（返金）")
	else:
		carrying.position = _from_pos
		carrying.rotation.y = _from_yaw
		_after_move(carrying)
	carrying = null
	_bought = 0
	_ghost.visible = false


func place() -> bool:
	if not _valid:
		Game.say("そこには置けない（ほかの物・カウンター・入口にかぶっている）")
		return false
	_after_move(carrying)
	if _bought > 0:
		Game.say("%sを置いた" % carrying.get_meta("pl_name"))
	carrying = null
	_bought = 0
	_ghost.visible = false
	Game.main.rebake()
	return true


func sell() -> void:
	var n := carrying
	if not (n is DiningTable or n.name.begins_with("Plant")):
		Game.say("厨房の設備は売れない（動かすだけ）")
		return
	if n is DiningTable and Game.main.tables.size() <= 1 and _bought == 0:
		Game.say("最後のテーブルは売れない")
		return
	var back: int = _bought if _bought > 0 else int(n.get_meta("pl_price")) / 2
	Game.add_money(back)
	Game.say("%sを売った（+%s）" % [n.get_meta("pl_name"), Game.yen(back)])
	_remove(n)
	carrying = null
	_bought = 0
	_ghost.visible = false
	Game.main.rebake()


func _remove(n: Node3D) -> void:
	if n is DiningTable:
		Game.main.tables.erase(n)
		Game.main.grills.erase(n.grill)
		Game.main.shadow_lights.erase(n.light)
		for i in Game.main.tables.size():
			Game.main.tables[i].index = i + 1
			Game.main.tables[i].grill.title = "テーブル%dの七輪" % (i + 1)
	n.queue_free()


func buy(kind: String) -> void:
	var price := 25000 if kind == "table" else 4000
	if Game.money < price:
		Game.say("お金が足りない")
		return
	if carrying:
		return
	Game.add_money(-price)
	var p: Player = Game.main.player
	var at: Vector3 = p.global_position - p.global_transform.basis.z * 2.0
	var n: Node3D
	if kind == "table":
		n = ShopBuilder.add_table(Game.main, Vector3(at.x, 0, at.z), 0.0)
	else:
		n = ShopBuilder.add_plant(Game.main, Vector3(at.x, 0, at.z), 0.0)
	close_shop()
	carrying = n
	_bought = price
	_from_pos = n.position
	_from_yaw = 0.0
	Game.say("%sを買った。置きたい所で左クリック（R で回す、右クリックでやめる）" % n.get_meta("pl_name"))


func set_wall(k: String) -> void:
	if k == wall_name:
		return
	if Game.money < WALL_PRICE:
		Game.say("お金が足りない")
		return
	Game.add_money(-WALL_PRICE)
	wall_name = k
	_recolor(Game.main.wall_mat, WALLS[k])
	Game.say("壁紙を「%s」にした" % k)
	open_shop()


func set_floor(k: String) -> void:
	if k == floor_name:
		return
	if Game.money < FLOOR_PRICE:
		Game.say("お金が足りない")
		return
	Game.add_money(-FLOOR_PRICE)
	floor_name = k
	_recolor(Game.main.floor_mat, FLOORS[k])
	Game.say("床を「%s」にした" % k)
	open_shop()


func _recolor(m: StandardMaterial3D, cols: Array) -> void:
	var g := Gradient.new()
	g.set_color(0, cols[0])
	g.set_color(1, cols[1])
	(m.albedo_texture as NoiseTexture2D).color_ramp = g


func expand() -> void:
	if expanded:
		return
	if Game.money < EXPAND_PRICE:
		Game.say("お金が足りない（%s 必要）" % Game.yen(EXPAND_PRICE))
		return
	Game.add_money(-EXPAND_PRICE)
	expanded = true
	ShopBuilder.expand_east(Game.main)
	Game.main.rebake()
	Game.say("隣の区画を買った！東側が4m広くなった")
	open_shop()


func _after_move(n: Node3D) -> void:
	if n is DiningTable:
		n.refresh_chairs()


func _process(_dt: float) -> void:
	if not active:
		return
	var p: Player = Game.main.player
	var cam: Camera3D = p.cam
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var lbl: Label = _panel.get_node("L")
	if carrying:
		# 視線と床の交わる所へ（遠すぎるときは 4m 先）
		var t := 4.0
		if dir.y < -0.05:
			t = minf(-from.y / dir.y, 6.0)
		var hit: Vector3 = from + dir * t
		var pos := Vector3(snappedf(hit.x, GRID), 0, snappedf(hit.z, GRID))
		carrying.position = pos
		_valid = fits(carrying, pos, carrying.rotation.y)
		var sz := footprint(carrying, carrying.rotation.y)
		_ghost.visible = true
		_ghost.position = pos + Vector3(0, 0.03, 0)
		_ghost.scale = Vector3(sz.x, 1, sz.y)
		_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if _valid else Color(1.0, 0.25, 0.2, 0.45)
		lbl.text = "【お店づくり】%s を移動中%s\n左クリック: 置く　R/ホイール: 回す　右クリック: やめる%s" % [carrying.get_meta("pl_name"), "" if _valid else "（ここには置けない）", "　X: 売る" if (carrying is DiningTable or carrying.name.begins_with("Plant")) else ""]
		Game.hud.set_hint("", false)
	else:
		_look = null
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 6.0, 1 | 2, [p.get_rid()])
		var r: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			var n: Node = r.collider
			while n and n != Game.main:
				if n.is_in_group("placeable"):
					_look = n
					break
				n = n.get_parent()
		lbl.text = "【お店づくり】　左クリック: 見ている設備を持ち上げる　T: カタログ（買う・壁紙・床・拡張）　B: 終わる\n所持金 %s" % Game.yen(Game.money)
		Game.hud.set_hint(("左クリック: %sを動かす" % _look.get_meta("pl_name")) if _look else "", _look != null)


static func footprint(n: Node3D, yaw: float) -> Vector2:
	var s: Vector2 = n.get_meta("pl_size")
	var q := int(round(yaw / (PI / 2)))
	return Vector2(s.y, s.x) if q % 2 != 0 else s


static func _rect(c: Vector3, s: Vector2) -> Rect2:
	return Rect2(c.x - s.x / 2, c.z - s.y / 2, s.x, s.y)


## その場所に置けるか（壁の内側・ほかの設備・カウンター・入口・段ボール置き場にかぶらない）
func fits(n: Node3D, pos: Vector3, yaw: float) -> bool:
	var r := _rect(pos, footprint(n, yaw))
	var room := Rect2(-ShopBuilder.W / 2, -ShopBuilder.D / 2, Game.main.room_max_x + ShopBuilder.W / 2, ShopBuilder.D)
	if not room.encloses(r):
		return false
	for z in [Rect2(-4.7, -1.6, 6.4, 1.65), Rect2(3.7, 3.2, 1.8, 1.4), Rect2(3.0, -4.5, 1.6, 0.95)]:
		if z.intersects(r):
			return false
	if expanded:
		# もとの壁の柱
		for z in [Rect2(5.85, -4.5, 0.3, 0.3), Rect2(5.85, 4.2, 0.3, 0.3)]:
			if z.intersects(r):
				return false
	for o in get_tree().get_nodes_in_group("placeable"):
		if o == n or o.is_queued_for_deletion():
			continue
		var orr := _rect(o.position, footprint(o, o.rotation.y))
		if orr.grow(-0.01).intersects(r.grow(-0.01)):
			return false
	return true
