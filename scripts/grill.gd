class_name Grill
extends Node3D
## 七輪。炭の量と空気口で火力が決まり、網の中央ほど熱い。脂が落ちると炎が上がる

const R := 0.15
const GRATE_Y := 0.205

var grate: Grate = null
var coal := 0.8
var vent := 0.5
var heat := 0.0
var flare := 0.0
var meats: Array[Meat] = []
var title := "七輪"

var _smoke: GPUParticles3D
var _fire: GPUParticles3D
var _light: OmniLight3D
var _coal_mat: StandardMaterial3D
var _coals: Array[MeshInstance3D] = []
var _sizzle: Sizzle
var _t := 0.0


func _ready() -> void:
	var clay := Build.noise_mat(Color(0.62, 0.52, 0.40), Color(0.75, 0.65, 0.52), 0.05, Vector3(4, 4, 4), 0.95, randi())
	Build.cyl(self, 0.19, 0.155, 0.19, Vector3(0, 0.095, 0), clay, true, 40)
	Build.cyl(self, 0.195, 0.195, 0.025, Vector3(0, 0.17, 0), Build.mat(Color(0.12, 0.12, 0.13), 0.5, 0.7), false, 40)
	Build.cyl(self, 0.165, 0.165, 0.012, Vector3(0, 0.188, 0), Build.mat(Color(0.03, 0.025, 0.02), 1.0), false, 40)
	Build.box(self, Vector3(0.07, 0.045, 0.01), Vector3(0, 0.05, 0.172), Build.mat(Color(0.1, 0.08, 0.06), 0.8), false)
	_coal_mat = Build.glow_mat(Color(1.0, 0.32, 0.06), 2.0)
	_coal_mat.albedo_color = Color(0.08, 0.05, 0.04)
	_coal_mat.roughness = 1.0
	for i in 9:
		var a := TAU * i / 9.0 + randf() * 0.3
		var r := 0.03 + (i % 3) * 0.04
		var c := Build.box(self, Vector3(0.055, 0.035, 0.045), Vector3(cos(a) * r, 0.17, sin(a) * r), _coal_mat, false)
		c.rotation = Vector3(randf() * 0.5, randf() * TAU, randf() * 0.5)
		_coals.append(c)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.45, 0.15)
	_light.omni_range = 0.9
	_light.position = Vector3(0, 0.16, 0)
	add_child(_light)
	_build_particles()
	_sizzle = Sizzle.new()
	_sizzle.position = Vector3(0, 0.22, 0)
	add_child(_sizzle)
	var g := Grate.new()
	add_child(g)
	install_grate(g)


func _build_particles() -> void:
	_smoke = GPUParticles3D.new()
	_smoke.amount = 48
	_smoke.lifetime = 2.2
	_smoke.position = Vector3(0, GRATE_Y + 0.02, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.11, 0.005, 0.11)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, 0.28, 0)
	pm.damping_min = 0.05
	pm.damping_max = 0.15
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.25))
	sc.add_point(Vector2(1, 1.8))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var gr := Gradient.new()
	gr.set_color(0, Color(0.85, 0.85, 0.85, 0.0))
	gr.set_color(1, Color(0.7, 0.7, 0.72, 0.0))
	gr.add_point(0.15, Color(0.85, 0.84, 0.82, 0.32))
	gr.add_point(0.6, Color(0.75, 0.75, 0.76, 0.16))
	var grt := GradientTexture1D.new()
	grt.gradient = gr
	pm.color_ramp = grt
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	_smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = Build.soft_texture()
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.proximity_fade_enabled = true
	sm.proximity_fade_distance = 0.08
	sm.albedo_color = Color(0.55, 0.52, 0.5)
	q.material = sm
	_smoke.draw_pass_1 = q
	add_child(_smoke)

	_fire = GPUParticles3D.new()
	_fire.amount = 40
	_fire.lifetime = 0.45
	_fire.position = Vector3(0, 0.18, 0)
	var fm := ParticleProcessMaterial.new()
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fm.emission_box_extents = Vector3(0.09, 0.01, 0.09)
	fm.direction = Vector3(0, 1, 0)
	fm.spread = 10.0
	fm.initial_velocity_min = 0.25
	fm.initial_velocity_max = 0.55
	fm.gravity = Vector3(0, 0.6, 0)
	fm.scale_min = 0.6
	fm.scale_max = 1.3
	var fg := Gradient.new()
	fg.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	fg.set_color(1, Color(0.8, 0.15, 0.02, 0.0))
	var fgt := GradientTexture1D.new()
	fgt.gradient = fg
	fm.color_ramp = fgt
	_fire.process_material = fm
	var fq := QuadMesh.new()
	fq.size = Vector2(0.07, 0.1)
	var fmat := StandardMaterial3D.new()
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.albedo_texture = Build.soft_texture()
	fmat.vertex_color_use_as_albedo = true
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(2.5, 1.6, 0.8)
	fq.material = fmat
	_fire.draw_pass_1 = fq
	_fire.amount_ratio = 0.0
	add_child(_fire)


func install_grate(g: Grate) -> void:
	g.detach()
	if g.get_parent() != self:
		g.reparent(self, false)
	g.position = Vector3(0, GRATE_Y, 0)
	g.rotation = Vector3.ZERO
	g.container = self
	g.set_placed()
	grate = g


func remove_item(n: Node) -> void:
	if n == grate:
		grate = null
	if n is Meat:
		meats.erase(n)


func is_sticky() -> bool:
	return grate != null and grate.dirt > 0.7


func heat_at(lp: Vector3) -> float:
	var r := Vector2(lp.x, lp.z).length() / R
	return heat * (1.0 - 0.5 * r * r) + flare * 0.7


func _process(dt: float) -> void:
	_t += dt
	var cf := clampf(coal * 1.6, 0.0, 1.0)
	var target := cf * (0.35 + 0.85 * vent)
	heat = lerpf(heat, target, 1.0 - exp(-dt / 4.0))
	if coal > 0.0:
		coal = maxf(0.0, coal - dt * (0.0010 + 0.0022 * vent))
	flare = maxf(0.0, flare - dt * 1.4)
	var drip := 0.0
	var burnt := 0.0
	var cooking := 0.0
	for m in meats:
		var h := heat_at(m.position) if grate else 0.0
		m.cook(dt, h, grate.dirt if grate else 0.0)
		drip += m.last_drip
		burnt += m.burnt_amount()
		cooking += h
	if grate:
		grate.add_dirt(dt * (drip * 0.5 + burnt * 0.015))
	if drip > 0.0 and randf() < drip * heat * dt * 4.0:
		flare = 1.0
		_sizzle.pop(1.0)
	var flick := 0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 7.3 + 1.0)
	_smoke.amount_ratio = clampf(0.04 * heat + drip * 9.0 + burnt * 0.5 + flare * 0.4, 0.0, 1.0)
	_smoke.emitting = _smoke.amount_ratio > 0.01
	_fire.amount_ratio = flare
	_fire.emitting = flare > 0.02
	_light.light_energy = (0.1 + heat * 0.45) * flick + flare * 1.6
	_coal_mat.emission_energy_multiplier = (0.4 + heat * 3.0) * flick
	var show := int(ceil(clampf(coal, 0.0, 1.2) / 1.2 * _coals.size()))
	for i in _coals.size():
		_coals[i].visible = i < show
	_sizzle.intensity = clampf(cooking * 0.35 + drip * 6.0, 0.0, 1.3)


func get_hint(p: Player) -> String:
	var t := title
	if p.held is Meat:
		t += "\n左クリック: 網にのせる" if grate else "\n網がない（網をセットしてから）"
	elif p.held is Grate:
		t += "\n左クリック: 網をセット" if grate == null else "\nもう網がのっている"
	elif p.held is Charcoal:
		t += "\n左クリック: 炭を入れる" if grate == null else "\n網を外してから炭を入れる"
	elif p.held == null and grate:
		t += "\n左クリック: 網を外す" if meats.is_empty() else "\n肉をどけると網を外せる"
	t += "\nホイール: 空気口（火力）"
	return t


func get_info(_p: Player) -> String:
	var lines := [
		title,
		"火力  %s" % Game.bar(heat / 1.2),
		"空気口  %d%%" % int(vent * 100),
		"炭  %s" % Game.bar(coal / 1.2),
		"網の汚れ  %s" % (Game.bar(grate.dirt) if grate else "（網なし）"),
	]
	if is_sticky():
		lines.append("網が汚れて焦げつきやすい！")
	return "\n".join(lines)


func primary(p: Player, pos: Vector3, _nrm: Vector3) -> bool:
	if p.held is Meat:
		if grate == null:
			Game.say("網がない")
			return true
		var m: Meat = p.held
		m.detach()
		m.reparent(self, false)
		var lp := to_local(pos)
		var v := Vector2(lp.x, lp.z)
		if v.length() > R - 0.03:
			v = v.normalized() * (R - 0.03)
		m.position = Vector3(v.x, GRATE_Y + 0.003 + m.data.t * 0.5, v.y)
		m.rotation = Vector3(PI if m.flipped else 0.0, p.rotation.y - global_rotation.y, 0.0)
		m.container = self
		m.set_placed()
		meats.append(m)
		return true
	if p.held is Grate:
		if grate == null:
			install_grate(p.held)
		return true
	if p.held is Charcoal:
		if grate:
			Game.say("網を外してから炭を入れよう")
			return true
		if coal >= 1.15:
			Game.say("炭はもう十分")
			return true
		var c: Item = p.held
		c.detach()
		c.queue_free()
		coal = minf(coal + 0.3, 1.2)
		return true
	if p.held == null and grate and meats.is_empty():
		p.pick(grate)
		return true
	return false


func scroll(_p: Player, dir: int) -> void:
	vent = clampf(vent + dir * 0.1, 0.0, 1.0)
