class_name JugRack
extends Node3D
## きれいなジョッキの棚

var _glasses: Array[MeshInstance3D] = []


func _ready() -> void:
	var wood := Build.noise_mat(Color(0.4, 0.26, 0.14), Color(0.55, 0.37, 0.2), 0.08, Vector3(1, 6, 1), 0.8, 21)
	Build.box(self, Vector3(0.4, 0.03, 0.3), Vector3(0, 0.015, 0), wood)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.92, 0.95, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	for i in 8:
		var g := Build.cyl(self, 0.045, 0.043, 0.15, Vector3(-0.14 + (i % 4) * 0.095, 0.105, -0.06 + (i / 4) * 0.12), glass, false, 16)
		_glasses.append(g)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.4, 0.2, 0.3)
	cs.shape = b
	cs.position.y = 0.1
	sb.add_child(cs)
	add_child(sb)


func _process(_dt: float) -> void:
	for i in _glasses.size():
		_glasses[i].visible = i < Game.clean_jugs


func get_hint(p: Player) -> String:
	var t := "ジョッキ棚（きれいなジョッキ %d個）" % Game.clean_jugs
	if p.held == null:
		t += "\n左クリック: ジョッキを取る" if Game.clean_jugs > 0 else "\nジョッキがない！シンクで洗おう"
	elif p.held is Drink and p.held.drink == "" and not p.held.empty_used:
		t += "\n左クリック: 戻す"
	return t


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	if p.held == null:
		if Game.clean_jugs <= 0:
			Game.say("きれいなジョッキがない！シンクで洗おう")
			return true
		Game.clean_jugs -= 1
		var j := Drink.new()
		Game.main.items_root.add_child(j)
		p.pick(j)
		return true
	if p.held is Drink and p.held.drink == "" and not p.held.empty_used:
		var j: Item = p.held
		j.detach()
		j.queue_free()
		Game.clean_jugs += 1
		return true
	return false
