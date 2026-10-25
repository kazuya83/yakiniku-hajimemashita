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
	_cross.position = Vector2(-3, -3)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cross)

	_status = _make_label(root, 22)
	_status.position = Vector2(24, 18)

	_orders = _make_label(root, 20)
	_orders.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_orders.position = Vector2(-360, 18)
	_orders.size = Vector2(340, 200)
	_orders.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_hint = _make_label(root, 22)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(900, 120)
	_hint.position = Vector2(-450, -170)

	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_info_panel.position = Vector2(-380, -120)
	_info_panel.custom_minimum_size = Vector2(340, 0)
	_info_panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55)))
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_info_panel)
	_info = _make_label(_info_panel, 20)

	_toast = _make_label(root, 30)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(1000, 60)
	_toast.position = Vector2(-500, 90)

	_help = _make_label(root, 19)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.position = Vector2(24, -250)
	_help.text = "WASD: 移動　Shift: 走る　マウス: 見る\n左クリック: つかむ・置く　右クリック: ひっくり返す\nホイール: 火力・部位を変える　E: 使う（長押しで洗う）\nEsc: メニュー　H: この説明を消す"

	_build_pause(root)
	_build_summary(root)
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
	_pause.position = Vector2(-220, -200)
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
	_summary.position = Vector2(-260, -200)
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
	_start.position = Vector2(-330, -260)
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
	d.text = "WASD（または矢印キー）: 歩く　Shift: 走る　マウス: 見まわす\n左クリック: つかむ・置く　右クリック: 肉をひっくり返す\nホイール: 七輪の火力・冷蔵庫の部位　E: 使う（長押しで網を洗う）\nEsc: メニュー・画質\n\n1. 奥の冷蔵庫で肉を出す\n2. カウンターの七輪で焼く\n3. 入口の札をEで開店\n4. お客さんの取り皿に、注文の肉を焼いて出す"
	v.add_child(d)
	var b := _button("はじめる（クリック）", func(): _begin())
	v.add_child(b)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	b.grab_focus.call_deferred()


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
