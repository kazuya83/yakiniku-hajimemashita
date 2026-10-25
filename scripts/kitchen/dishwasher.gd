class_name Dishwasher
extends Node3D
## 食洗機。Eで洗い物をまとめて入れて洗う（1回 最大20個・約25秒）

const CAPACITY := 20
const CYCLE := 25.0

var plates := 0
var jugs := 0
var running := 0.0
var _lamp: MeshInstance3D
var _door: MeshInstance3D
var _steam: GPUParticles3D


func _ready() -> void:
	var steel := Build.mat(Color(0.74, 0.75, 0.77), 0.3, 0.9)
	Build.box(self, Vector3(0.65, 0.85, 0.65), Vector3(0, 0.425, 0), steel)
	_door = Build.box(self, Vector3(0.6, 0.55, 0.02), Vector3(0, 0.5, 0.33), Build.mat(Color(0.6, 0.61, 0.63), 0.25, 1.0), false)
	Build.box(self, Vector3(0.4, 0.03, 0.03), Vector3(0, 0.7, 0.35), Build.mat(Color(0.2, 0.2, 0.2), 0.4), false)
	_lamp = Build.sphere(self, 0.02, Vector3(0.24, 0.8, 0.33), Build.glow_mat(Color(0.2, 1.0, 0.3), 2.0))
	var l := Build.label(self, "食洗機", Vector3(-0.12, 0.8, 0.335), 40, Color(0.15, 0.15, 0.18))
	l.double_sided = false
	_steam = GPUParticles3D.new()
	_steam.amount = 20
	_steam.lifetime = 1.5
	_steam.position = Vector3(0, 0.86, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	_steam.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 1, 1, 0.12)
	sm.albedo_texture = Build.soft_texture()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = sm
	_steam.draw_pass_1 = q
	_steam.emitting = false
	add_child(_steam)
	ShopBuilder.placeable(self, "食洗機", Vector2(0.65, 0.65), 80000)


func _process(dt: float) -> void:
	_steam.emitting = running > 0.0
	if running > 0.0:
		running -= dt
		(_lamp.material_override as StandardMaterial3D).emission = Color(1.0, 0.5, 0.1)
		if running <= 0.0:
			Game.clean_plates += plates
			Game.clean_jugs += jugs
			Game.say("食洗機が終わった（皿%d・ジョッキ%d がきれいに）" % [plates, jugs])
			plates = 0
			jugs = 0
	else:
		(_lamp.material_override as StandardMaterial3D).emission = Color(0.2, 1.0, 0.3)


func get_hint(_p: Player) -> String:
	if running > 0.0:
		return "食洗機（洗っている…あと%d秒）" % int(ceil(running))
	var t := "食洗機（洗い物: 皿 %d / ジョッキ %d）" % [Game.dirty_plates, Game.dirty_jugs]
	if Game.dirty_plates + Game.dirty_jugs > 0:
		t += "\nE: 洗い物を入れて洗う（最大%d個）" % CAPACITY
	return t


func use(_p: Player) -> void:
	start()


func start() -> bool:
	if running > 0.0 or Game.dirty_plates + Game.dirty_jugs == 0:
		return false
	plates = mini(Game.dirty_plates, CAPACITY)
	jugs = mini(Game.dirty_jugs, CAPACITY - plates)
	Game.dirty_plates -= plates
	Game.dirty_jugs -= jugs
	running = CYCLE
	Game.say("食洗機に皿%d・ジョッキ%dを入れて回した" % [plates, jugs])
	return true
