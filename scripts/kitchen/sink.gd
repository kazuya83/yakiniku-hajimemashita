class_name Sink
extends Node3D
## シンク。汚れた網を入れて、E長押しで洗う

var grate: Grate = null
var _water: GPUParticles3D
var _washing := 0.0


func _ready() -> void:
	var steel := Build.mat(Color(0.7, 0.71, 0.73), 0.3, 0.9)
	Build.box(self, Vector3(1.0, 0.85, 0.65), Vector3(0, 0.425, 0), steel)
	Build.box(self, Vector3(0.7, 0.02, 0.45), Vector3(0, 0.86, 0), Build.mat(Color(0.3, 0.31, 0.33), 0.2, 0.9), false)
	Build.cyl(self, 0.015, 0.015, 0.3, Vector3(0, 1.0, -0.28), steel)
	var spout := Build.cyl(self, 0.012, 0.012, 0.16, Vector3(0, 1.14, -0.21), steel)
	spout.rotation.x = PI / 2
	_water = GPUParticles3D.new()
	_water.amount = 60
	_water.lifetime = 0.35
	_water.position = Vector3(0, 1.12, -0.14)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0, -6, 0)
	_water.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.04)
	var wm := StandardMaterial3D.new()
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(0.8, 0.9, 1.0, 0.5)
	wm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = wm
	_water.draw_pass_1 = q
	_water.emitting = false
	add_child(_water)


func _process(dt: float) -> void:
	_washing = maxf(_washing - dt, 0.0)
	_water.emitting = _washing > 0.0


func remove_item(n: Node) -> void:
	if n == grate:
		grate = null


func get_hint(p: Player) -> String:
	var t := "シンク"
	if grate:
		t += "\nE長押し: 網を洗う（汚れ %d%%）" % int(grate.dirt * 100)
		if p.held == null:
			t += "\n左クリック: 網を取り出す"
	elif p.held is Grate:
		t += "\n左クリック: 網を入れる"
	if p.held is Plate:
		t += "\n左クリック: 皿を下げる" if p.held.meats.is_empty() else "\n肉が残っている皿はゴミ箱へ"
	return t


func primary(p: Player, _pos: Vector3, _nrm: Vector3) -> bool:
	if p.held is Grate and grate == null:
		var g: Grate = p.held
		g.detach()
		g.reparent(self, false)
		g.position = Vector3(0, 0.88, 0)
		g.rotation = Vector3(0.12, 0, 0)
		g.container = self
		g.set_placed()
		grate = g
		return true
	if p.held == null and grate:
		p.pick(grate)
		return true
	if p.held is Plate:
		if not p.held.meats.is_empty():
			Game.say("肉が残っている皿はゴミ箱へ")
			return true
		var pl: Item = p.held
		pl.detach()
		pl.queue_free()
		Game.main.dirty_dishes += 1
		return true
	return false


func hold_use(_p: Player, dt: float) -> void:
	if grate == null:
		return
	_washing = 0.15
	var before := grate.dirt
	grate.clean(dt * 0.35)
	if before > 0.0 and grate.dirt <= 0.0:
		Game.say("網がピカピカになった！")
