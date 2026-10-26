class_name Hud
extends CanvasLayer
## 画面の表示（状態・照準・操作ヒント・詳細・お知らせ・メニュー）

var _status: Label
var _hint: Label
var _info: Label
var _info_panel: PanelContainer
var _toast: Label
var _toast_t := 0.0
var _cross: ColorRect
var _help: Label
var _pause: PanelContainer
var _summary: PanelContainer
var _summary_label: Label
var _orders: Label
var _start: PanelContainer
var _ticket: PanelContainer
var _ticket_title: Label
var _ticket_counts := {}
var _ticket_labels := {}
var _ticket_party: TableParty
var _buy: PanelContainer
var _buy_counts := {}
var _buy_labels := {}
var _buy_stock := {}
var _buy_total: Label
var _staff: PanelContainer
var _staff_labels := {}
var _staff_total: Label
var _rows := {}        # 伝票・発注の行（メニューにない部位は隠す）
var _block_ui := []    # 塊肉の発注ボタン（自家カットを買うまで隠す）


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_cross = ColorRect.new()
	_cross.size = Vector2(6, 6)
	_cross.color = Color(1, 1, 1, 0.85)
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	Hud.place(_cross, Vector2(-3, -3))
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cross)

	_status = _make_label(root, 22)
	_status.position = Vector2(24, 18)

	_orders = _make_label(root, 20)
	_orders.anchor_left = 1.0
	_orders.anchor_right = 1.0
	_orders.offset_left = -560
	_orders.offset_right = -24
	_orders.offset_top = 18
	_orders.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_orders.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

	_hint = _make_label(root, 22)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(900, 120)
	Hud.place(_hint, Vector2(-450, -170))

	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	Hud.place(_info_panel, Vector2(-380, -120))
	_info_panel.custom_minimum_size = Vector2(340, 0)
	_info_panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55)))
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_info_panel)
	_info = _make_label(_info_panel, 20)

	_toast = _make_label(root, 30)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(900, 60)
	_toast.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	Hud.place(_toast, Vector2(-450, 110))

	_help = _make_label(root, 19)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	Hud.place(_help, Vector2(24, -280))
	_help.text = "WASD・↑↓: 移動　← →: 向きを変える　Shift: 走る　マウス: 見る\n左クリック: つかむ・置く　右クリック: ひっくり返す\nホイール: 火力・部位を変える　E: 使う（長押しで洗う）\nB: お店づくり（開店前・閉店後）\nEsc: メニュー　H: この説明を消す"

	_build_pause(root)
	_build_summary(root)
	_build_ticket(root)
	_build_purchase(root)
	_build_staff(root)
	_build_start(root)
	Game.toast.connect(show_toast)


func _make_label(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _box(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	return sb


func _build_pause(root: Control) -> void:
	_pause = PanelContainer.new()
	_pause.set_anchors_preset(Control.PRESET_CENTER)
	Hud.place(_pause, Vector2(-220, -200))
	_pause.custom_minimum_size = Vector2(440, 0)
	_pause.add_theme_stylebox_override("panel", _box(Color(0.08, 0.05, 0.04, 0.92)))
	root.add_child(_pause)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_pause.add_child(v)
	var t := Label.new()
	t.text = "焼肉屋はじめました"
	t.add_theme_font_size_override("font_size", 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("再開する", func(): toggle_pause()))
	var ql := Label.new()
	ql.text = "画質"
	v.add_child(ql)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	for q in [["低", "low"], ["中", "mid"], ["高", "high"]]:
		var b := _button(q[0], func(): Game.main.apply_quality(q[1]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	v.add_child(_button("ゲームを終わる", func(): get_tree().quit()))
	_pause.visible = false


func _build_summary(root: Control) -> void:
	_summary = PanelContainer.new()
	_summary.set_anchors_preset(Control.PRESET_CENTER)
	Hud.place(_summary, Vector2(-260, -200))
	_summary.custom_minimum_size = Vector2(520, 0)
	_summary.add_theme_stylebox_override("panel", _box(Color(0.08, 0.05, 0.04, 0.94)))
	root.add_child(_summary)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_summary.add_child(v)
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 24)
	v.add_child(_summary_label)
	v.add_child(_button("寝て次の日へ（Enter）", func(): Game.main.next_day()))
	_summary.visible = false


func _build_start(root: Control) -> void:
	_start = PanelContainer.new()
	_start.set_anchors_preset(Control.PRESET_CENTER)
	Hud.place(_start, Vector2(-330, -260))
	_start.custom_minimum_size = Vector2(660, 0)
	_start.add_theme_stylebox_override("panel", _box(Color(0.08, 0.05, 0.04, 0.94)))
	root.add_child(_start)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_start.add_child(v)
	var t := Label.new()
	t.text = "焼肉屋はじめました"
	t.add_theme_font_size_override("font_size", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := Label.new()
	d.add_theme_font_size_override("font_size", 21)
	d.text = "WASD・↑↓: 歩く　← →: 向きを変える　Shift: 走る　マウス: 見まわす\n左クリック: つかむ・置く　右クリック: 肉をひっくり返す\nホイール: 七輪の火力・冷蔵庫の部位　E: 使う（長押しで網を洗う）\nEsc: メニュー・画質　B: お店づくり\n\nあなたは焼肉屋の店長。資金 ¥300,000 でスタート。\n1. 家から向かいのお店へ歩き、入口のタイムカードをEで押して出社\n2. 入口横のシフト表（E）でアルバイトを雇える\n　 焼き担当・ホール担当・片づけ担当にまかせるほど楽になる\n3. 札をEでひっくり返して開店。自分でも焼いて運んで、お店を育てよう"
	v.add_child(d)
	var b := _button("はじめから", func(): _begin())
	if SaveData.exists():
		var c := _button("続きから（%s）" % SaveData.summary(), func(): _continue())
		v.add_child(c)
		c.grab_focus.call_deferred()
		b.text = "はじめから（セーブは次の閉店後に上書きされる）"
	else:
		b.grab_focus.call_deferred()
	v.add_child(b)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_staff(root: Control) -> void:
	_staff = PanelContainer.new()
	_staff.set_anchors_preset(Control.PRESET_CENTER)
	Hud.place(_staff, Vector2(-380, -230))
	_staff.custom_minimum_size = Vector2(760, 0)
	_staff.add_theme_stylebox_override("panel", _box(Color(0.1, 0.12, 0.16, 0.96)))
	root.add_child(_staff)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_staff.add_child(v)
	var t := Label.new()
	t.text = "シフト表：アルバイトを雇う（日給は毎日の閉店後にはらう）"
	t.add_theme_font_size_override("font_size", 22)
	v.add_child(t)
	for role in Game.ROLES:
		var r: Dictionary = Game.ROLES[role]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		v.add_child(h)
		var n := Label.new()
		n.text = "%s　日給 %s\n%s" % [r.name, Game.yen(r.wage), r.desc]
		n.custom_minimum_size = Vector2(470, 0)
		n.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		n.add_theme_font_size_override("font_size", 18)
		h.add_child(n)
		h.add_child(_button("－", func(): staff_change(role, -1)))
		var cnt := Label.new()
		cnt.custom_minimum_size = Vector2(60, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", 22)
		h.add_child(cnt)
		_staff_labels[role] = cnt
		h.add_child(_button("＋", func(): staff_change(role, 1)))
	_staff_total = Label.new()
	_staff_total.add_theme_font_size_override("font_size", 20)
	v.add_child(_staff_total)
	v.add_child(_button("閉じる", func(): close_staff()))
	_staff.visible = false


func open_staff() -> void:
	_staff_refresh()
	_staff.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_staff() -> void:
	_staff.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func staff_change(role: String, d: int) -> void:
	if d > 0:
		if Game.main.staff.size() >= 8:
			show_toast("これ以上は雇えない（最大8人）")
			return
		Game.main.hire(role)
	else:
		Game.main.fire(role)
	_staff_refresh()


func _staff_refresh() -> void:
	for role in _staff_labels:
		_staff_labels[role].text = "%d人" % Game.main.staff_count(role)
	_staff_total.text = "日給の合計 %s　（所持金 %s）" % [Game.yen(Game.main.wages()), Game.yen(Game.money)]


func _build_ticket(root: Control) -> void:
	_ticket = PanelContainer.new()
	_ticket.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	Hud.place(_ticket, Vector2(30, -200))
	_ticket.custom_minimum_size = Vector2(360, 0)
	var sb := _box(Color(0.96, 0.94, 0.86, 0.97))
	_ticket.add_theme_stylebox_override("panel", sb)
	root.add_child(_ticket)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_ticket.add_child(v)
	_ticket_title = Label.new()
	_ticket_title.add_theme_font_size_override("font_size", 26)
	_ticket_title.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	v.add_child(_ticket_title)
	var note := Label.new()
	note.text = "聞いた注文を書きこもう（肉は皿、飲み物は杯）"
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", Color(0.35, 0.3, 0.25))
	v.add_child(note)
	for c in MeatData.ORDER + MeatData.DRINK_ORDER:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		v.add_child(h)
		_rows["t_" + c] = h
		var n := Label.new()
		n.text = MeatData.item_name(c)
		n.custom_minimum_size = Vector2(120, 0)
		n.add_theme_font_size_override("font_size", 22)
		n.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
		h.add_child(n)
		h.add_child(_button("－", func(): _ticket_add(c, -1)))
		var cnt := Label.new()
		cnt.custom_minimum_size = Vector2(40, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", 24)
		cnt.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
		h.add_child(cnt)
		_ticket_labels[c] = cnt
		h.add_child(_button("＋", func(): _ticket_add(c, 1)))
	v.add_child(_button("書けた", func(): _close_ticket()))
	_ticket.visible = false


func _build_purchase(root: Control) -> void:
	_buy = PanelContainer.new()
	_buy.set_anchors_preset(Control.PRESET_CENTER)
	Hud.place(_buy, Vector2(-330, -240))
	_buy.custom_minimum_size = Vector2(660, 0)
	_buy.add_theme_stylebox_override("panel", _box(Color(0.1, 0.12, 0.16, 0.96)))
	root.add_child(_buy)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_buy.add_child(v)
	var t := Label.new()
	t.text = "発注（1箱 = %d枚、翌朝届く。賞味期限は届いてから%d日）" % [Game.BOX_PIECES, Game.SHELF_DAYS]
	t.add_theme_font_size_override("font_size", 22)
	v.add_child(t)
	for c in MeatData.ORDER:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		v.add_child(h)
		_rows["b_" + c] = h
		var n := Label.new()
		n.text = "%s　1箱 %s" % [MeatData.CUTS[c].name, Game.yen(Game.box_cost(c))]
		n.custom_minimum_size = Vector2(230, 0)
		n.add_theme_font_size_override("font_size", 20)
		h.add_child(n)
		var st := Label.new()
		st.custom_minimum_size = Vector2(170, 0)
		st.add_theme_font_size_override("font_size", 18)
		h.add_child(st)
		_buy_stock[c] = st
		h.add_child(_button("－", func(): _buy_add(c, -1)))
		var cnt := Label.new()
		cnt.custom_minimum_size = Vector2(50, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", 22)
		h.add_child(cnt)
		_buy_labels[c] = cnt
		h.add_child(_button("＋", func(): _buy_add(c, 1)))
		# 塊肉（自家カット）
		var bn := Label.new()
		bn.text = "　塊 %s" % Game.yen(Game.block_cost(c))
		bn.add_theme_font_size_override("font_size", 18)
		h.add_child(bn)
		var bm := _button("－", func(): _buy_add("b_" + c, -1))
		h.add_child(bm)
		var bc := Label.new()
		bc.custom_minimum_size = Vector2(40, 0)
		bc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bc.add_theme_font_size_override("font_size", 22)
		h.add_child(bc)
		_buy_labels["b_" + c] = bc
		var bp := _button("＋", func(): _buy_add("b_" + c, 1))
		h.add_child(bp)
		_block_ui.append_array([bn, bm, bc, bp])
	_buy_total = Label.new()
	_buy_total.add_theme_font_size_override("font_size", 22)
	v.add_child(_buy_total)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var ok := _button("発注する", func(): _buy_confirm())
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ok)
	var cancel := _button("閉じる", func(): _buy_close())
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(cancel)
	_buy.visible = false


func open_purchase() -> void:
	for c in MeatData.ORDER:
		_rows["b_" + c].visible = MeatData.on_menu(c)
		_buy_counts[c] = 0
		_buy_labels[c].text = "0箱"
		_buy_counts["b_" + c] = 0
		_buy_labels["b_" + c].text = "0"
		var left := Game.stock_days_left(c)
		_buy_stock[c].text = "在庫 %d枚%s" % [Game.stock_count(c), ("・あと%d日" % left) if left >= 0 else ""]
	for u in _block_ui:
		u.visible = Game.has("selfcut")
	_buy_refresh()
	_buy.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _buy_add(c: String, d: int) -> void:
	_buy_counts[c] = clampi(_buy_counts[c] + d, 0, 9)
	_buy_labels[c].text = str(_buy_counts[c]) if c.begins_with("b_") else "%d箱" % _buy_counts[c]
	_buy_refresh()


func _buy_cost() -> int:
	var total := 0
	for c in _buy_counts:
		total += (Game.block_cost(c.substr(2)) if c.begins_with("b_") else Game.box_cost(c)) * _buy_counts[c]
	return total


func _buy_refresh() -> void:
	var pending := []
	for c in Game.orders:
		pending.append(("%s塊%d" % [MeatData.CUTS[c.substr(2)].name, Game.orders[c]]) if c.begins_with("b_") else ("%s%d箱" % [MeatData.CUTS[c].name, Game.orders[c]]))
	_buy_total.text = "合計 %s　（所持金 %s）%s" % [Game.yen(_buy_cost()), Game.yen(Game.money), ("\n明日届く予定: " + "・".join(pending)) if not pending.is_empty() else ""]


func _buy_confirm() -> void:
	var cost := _buy_cost()
	if cost <= 0:
		_buy_close()
		return
	if cost > Game.money:
		show_toast("お金が足りない")
		return
	Game.add_money(-cost)
	for c in _buy_counts:
		if _buy_counts[c] > 0:
			Game.orders[c] = Game.orders.get(c, 0) + _buy_counts[c]
	show_toast("発注した！明日の朝、段ボールで届きます")
	_buy_close()


func _buy_close() -> void:
	_buy.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func open_ticket(party: TableParty) -> void:
	_ticket_party = party
	_ticket_counts = {}
	for c in MeatData.ORDER + MeatData.DRINK_ORDER:
		_rows["t_" + c].visible = MeatData.is_drink(c) or MeatData.on_menu(c)
		_ticket_counts[c] = 0
		_ticket_labels[c].text = "0"
	_ticket_title.text = "伝票　テーブル%d" % party.table.index
	_ticket.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ticket_add(c: String, d: int) -> void:
	_ticket_counts[c] = clampi(_ticket_counts[c] + d, 0, 9)
	_ticket_labels[c].text = str(_ticket_counts[c])


func _close_ticket() -> void:
	if is_instance_valid(_ticket_party):
		var t := {}
		for c in _ticket_counts:
			if _ticket_counts[c] > 0:
				t[c] = _ticket_party.ticket.get(c, 0) + _ticket_counts[c]
			elif _ticket_party.ticket.has(c):
				t[c] = _ticket_party.ticket[c]
		_ticket_party.ticket = t
	_ticket.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 画面の基準点（アンカー）からのずれで置く。大きさは最小サイズか今の大きさ
static func place(c: Control, off: Vector2) -> void:
	var s := c.custom_minimum_size
	if s == Vector2.ZERO:
		s = c.size
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + s.x
	c.offset_bottom = off.y + s.y


func ticket_open() -> bool:
	return _ticket.visible or _buy.visible or _staff.visible or (Game.main.build != null and Game.main.build.shop_open())


func _continue() -> void:
	if not SaveData.load_into(Game.main):
		Game.say("セーブを読み込めなかった。はじめから始めます")
	_begin()


func _begin() -> void:
	_start.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b


func toggle_pause() -> void:
	if _summary.visible or _start.visible:
		return
	var p := not get_tree().paused
	get_tree().paused = p
	_pause.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func show_summary(text: String) -> void:
	_summary_label.text = text
	_summary.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_summary() -> void:
	_summary.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func summary_visible() -> bool:
	return _summary.visible


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		toggle_pause()
	elif e.is_action_pressed("help"):
		_help.visible = not _help.visible
	elif e.is_action_pressed("next_day") and _summary.visible:
		Game.main.next_day()


func set_hint(t: String, targeted: bool) -> void:
	_hint.text = t
	_cross.color = Color(1, 0.85, 0.3, 0.95) if targeted else Color(1, 1, 1, 0.7)


func set_info(t: String) -> void:
	_info.text = t
	_info_panel.visible = t != ""


func set_status(t: String) -> void:
	_status.text = t


func set_orders(t: String) -> void:
	_orders.text = t


func show_toast(t: String) -> void:
	_toast.text = t
	_toast_t = 3.0
	_toast.modulate.a = 1.0


func _process(dt: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= dt
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
