class_name GrateRack
extends Node3D
## きれいな網の置き場

var count := 3
var _discs: Array[MeshInstance3D] = []


func _ready() -> void:
	var wood := Build.noise_mat(Color(0.4, 0.26, 0.14), Color(0.55, 0.37, 0.2), 0.08, Vector3(1, 6, 1), 0.8, 9)
	Build.box(self, Vector3(0.45, 0.85, 0.42), Vector3(0, 0.425, 0), wood)
	var steel := Build.mat(Color(0.72, 0.72, 0.74), 0.35, 1.0)
	for i in 6:
		var d := Build.cyl(self, 0.165, 0.165, 0.006, Vector3(0, 0.86 + i * 0.008, 0), steel, false, 32)
		_discs.append(d)
	_refresh()


func _refresh() -> void:
	for i in _discs.size():
		_discs[i].visible = i < count


func get_hint(p: Player) -> String:
	var t := "網置き場（きれいな網 %d枚）" % count
	if p.held == null and count > 0:
		t += "\n左クリック: 網を取る"
	elif p.held is Grate:
		t += "\n左クリック: 網を戻す" if p.held.dirt < 0.1 else "\n汚れた網はシンクで洗ってから"
	return t


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	if p.held == null and count > 0:
		count -= 1
		_refresh()
		var g := Grate.new()
		Game.main.items_root.add_child(g)
		p.pick(g)
		return true
	if p.held is Grate:
		if p.held.dirt >= 0.1:
			Game.say("汚れた網はシンクで洗ってから戻そう")
			return true
		if count >= _discs.size():
			Game.say("網置き場がいっぱい")
			return true
		var g: Item = p.held
		g.detach()
		g.queue_free()
		count += 1
		_refresh()
		return true
	return false
