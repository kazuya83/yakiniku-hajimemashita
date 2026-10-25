class_name DrinkTap
extends Node3D
## ビールサーバー・ハイボールタワー・ウーロン茶ディスペンサー。ジョッキを持ってE長押しで注ぐ

var drink := "beer"
var tilt := 30.0   # ジョッキの傾き（度）。傾けて注ぐと泡が少ない
var _pour_t := 0.0
var _stream: MeshInstance3D
var _spilled := false


func _ready() -> void:
	var steel := Build.mat(Color(0.75, 0.76, 0.78), 0.25, 1.0)
	match drink:
		"beer":
			Build.box(self, Vector3(0.32, 0.42, 0.4), Vector3(0, 0.21, 0), steel)
			Build.box(self, Vector3(0.3, 0.12, 0.02), Vector3(0, 0.33, 0.201), Build.mat(Color(0.75, 0.1, 0.08), 0.5), false)
			Build.label(self, "生", Vector3(0, 0.33, 0.215), 80).double_sided = false
			Build.cyl(self, 0.015, 0.015, 0.12, Vector3(0, 0.5, 0.15), Build.mat(Color(0.1, 0.1, 0.1), 0.4), false)
		"highball":
			Build.box(self, Vector3(0.22, 0.36, 0.3), Vector3(0, 0.18, 0), Build.mat(Color(0.12, 0.1, 0.08), 0.4))
			Build.label(self, "ハイボール", Vector3(0, 0.25, 0.155), 44, Color(0.95, 0.85, 0.5)).double_sided = false
			Build.cyl(self, 0.04, 0.04, 0.2, Vector3(0, 0.46, -0.05), Build.mat(Color(0.6, 0.35, 0.1, 1), 0.2), false)
		_:
			Build.box(self, Vector3(0.22, 0.36, 0.3), Vector3(0, 0.18, 0), Build.mat(Color(0.85, 0.85, 0.82), 0.4))
			Build.label(self, "ウーロン茶", Vector3(0, 0.25, 0.155), 44, Color(0.3, 0.15, 0.05)).double_sided = false
	Build.cyl(self, 0.012, 0.012, 0.06, Vector3(0, 0.4, 0.17), steel, false, 12)
	_stream = Build.cyl(self, 0.006, 0.006, 0.18, Vector3(0, 0.28, 0.17), Build.mat(MeatData.DRINKS[drink].color, 0.1), false, 8)
	_stream.visible = false
	Build.box(self, Vector3(0.18, 0.01, 0.14), Vector3(0, 0.005, 0.24), Build.mat(Color(0.3, 0.3, 0.32), 0.3, 0.8), false)


func _process(dt: float) -> void:
	_pour_t = maxf(_pour_t - dt, 0.0)
	_stream.visible = _pour_t > 0.0


func _ok_jug(p: Player) -> bool:
	return p.held is Drink and not p.held.empty_used and (p.held.drink == "" or p.held.drink == drink)


func get_hint(p: Player) -> String:
	var t: String = MeatData.DRINKS[drink].name + ("サーバー" if drink == "beer" else "")
	if _ok_jug(p):
		t += "\nE長押し: 注ぐ"
		if drink == "beer":
			t += "\nホイール: ジョッキの傾き（いま %d度）\n傾けて注ぐと泡が少なく、まっすぐだと泡が多い" % int(tilt)
	elif p.held == null:
		t += "\n先にジョッキ棚でジョッキを取る"
	return t


func get_info(p: Player) -> String:
	if p.held is Drink:
		return p.held.get_info(p)
	return ""


func scroll(_p: Player, d: int) -> void:
	tilt = clampf(tilt + d * 5.0, 0.0, 45.0)


func hold_use(p: Player, dt: float) -> void:
	if not _ok_jug(p):
		return
	var j: Drink = p.held
	if j.drink == "":
		_spilled = false
	j.drink = drink
	_pour_t = 0.12
	var v := 0.2 * dt
	if drink == "beer":
		var fr := lerpf(0.7, 0.05, tilt / 45.0)
		j.level += v * (1.0 - fr)
		j.foam += v * fr
		j.rotation.z = -deg_to_rad(tilt)
	else:
		j.level += v * 1.2
	var over := j.level + j.foam - 1.0
	if over > 0.0:
		var f := minf(j.foam, over)
		j.foam -= f
		j.level -= over - f
		if not _spilled:
			_spilled = true
			Game.say("あふれた！")
	j.refresh()
