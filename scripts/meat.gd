class_name Meat
extends Item
## 肉1枚。上の面・下の面・中の火の通り・脂を持ち、網の熱で焼ける

const SHADER := preload("res://shaders/meat.gdshader")

var cut := "karubi"
var data: Dictionary
var sear := [0.0, 0.0]  # [自分の上面(+Y), 自分の下面(-Y)]
var core := 0.0
var fat := 1.0
var flipped := false  # true のとき、自分の上面が網に当たっている
var dropped := false
var flipping := false
var last_drip := 0.0
var mat: ShaderMaterial


func setup(c: String) -> Meat:
	cut = c
	kind = "meat"
	data = MeatData.CUTS[c]
	fat = data.fat
	var sd := randf() * 100.0
	var mi := MeshInstance3D.new()
	mi.mesh = MeatData.build_mesh(data, sd)
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("raw_color", data.color)
	mat.set_shader_parameter("fat_color", data.fat_color)
	mat.set_shader_parameter("marbling", data.marbling)
	mat.set_shader_parameter("seed", sd)
	mi.material_override = mat
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(data.w, maxf(data.t, 0.014), data.d)
	cs.shape = bs
	add_child(cs)
	_update_mat()
	return self


func rest_offset() -> float:
	return data.t * 0.5


func display_name() -> String:
	return data.name


## 網の上で焼く。h はこの位置の熱、dirt は網の汚れ
func cook(dt: float, h: float, dirt: float) -> void:
	if flipping:
		h *= 0.3
	h = maxf(h, 0.0)
	var down := 0 if flipped else 1
	sear[down] += h * data.sear_k * 0.034 * dt * (1.0 + dirt * 0.6)
	sear[1 - down] += h * 0.0025 * dt
	core += h * 0.018 * (0.008 / data.t) * dt
	last_drip = 0.0
	if fat > 0.02 and core > 0.12:
		var d: float = h * 0.012 * data.fat * dt
		fat = maxf(fat - d, 0.0)
		last_drip = d / maxf(dt, 0.0001)
	_update_mat()


func burnt_amount() -> float:
	return maxf(maxf(sear[0], sear[1]) - 1.05, 0.0)


func _update_mat() -> void:
	mat.set_shader_parameter("sear_top", sear[0])
	mat.set_shader_parameter("sear_bottom", sear[1])
	mat.set_shader_parameter("mark_top", clampf((sear[0] - 0.3) * 1.6, 0.0, 1.0))
	mat.set_shader_parameter("mark_bottom", clampf((sear[1] - 0.3) * 1.6, 0.0, 1.0))
	mat.set_shader_parameter("core", core)
	mat.set_shader_parameter("fat", fat / maxf(data.fat, 0.01))


func flip(sticky: bool) -> void:
	if flipping:
		return
	if sticky and randf() < 0.35:
		Game.say("網にくっついた！もう一度")
		var down := 0 if flipped else 1
		sear[down] += 0.05
		_update_mat()
		return
	flipping = true
	var y0 := position.y
	var tw := create_tween()
	tw.tween_property(self, "position:y", y0 + 0.05, 0.12)
	tw.parallel().tween_property(self, "rotation:x", rotation.x + PI, 0.25)
	tw.tween_property(self, "position:y", y0, 0.1)
	tw.tween_callback(func():
		flipped = not flipped
		flipping = false
	)


func state_word() -> String:
	if dropped:
		return "床に落ちた"
	if maxf(sear[0], sear[1]) > 1.1:
		return "焦げ"
	if core < 0.3:
		return "生"
	if core < data.ideal.x:
		return "レア"
	if core <= data.ideal.y:
		return "ちょうどいい"
	return "よく焼き"


## お客さんの評価 0〜1
func score() -> float:
	if dropped:
		return 0.0
	var s := 1.0
	var lo: float = data.ideal.x
	var hi: float = data.ideal.y
	if core < lo:
		s -= (lo - core) * 2.2
	elif core > hi:
		s -= (core - hi) * 1.6
	for i in 2:
		if sear[i] > 1.1:
			s -= 0.45
		elif sear[i] > 1.0:
			s -= 0.15
		elif sear[i] < 0.35:
			s -= 0.2
	return clampf(s, 0.0, 1.0)


func get_hint(p: Player) -> String:
	var t := "%s（%s）" % [data.name, state_word()]
	if p.held == null:
		t += "\n左クリック: トングでつかむ"
	elif p.held is Plate:
		t += "\n左クリック: 皿にとる"
	elif container and container.has_method("get_hint"):
		return container.get_hint(p)
	if container is Grill:
		t += "\n右クリック: ひっくり返す"
	return t


func primary(p: Player, pos: Vector3, nrm: Vector3) -> bool:
	if p.held is Plate:
		if p.held.add_meat(self):
			return true
		Game.say("皿がいっぱい")
		return true
	return super.primary(p, pos, nrm)


func secondary(_p: Player) -> bool:
	if container is Grill:
		flip(container.is_sticky())
		return true
	return false


func get_info(_p: Player) -> String:
	var down := "上の面" if flipped else "下の面"
	var up := "下の面" if flipped else "上の面"
	var lines := [
		"%s　%s" % [data.name, state_word()],
		"網側(%s)  %s" % [down, Game.bar(sear[0 if flipped else 1] / 1.2)],
		"上側(%s)  %s" % [up, Game.bar(sear[1 if flipped else 0] / 1.2)],
		"中の火通り  %s" % Game.bar(core / 1.2),
		"脂  %s" % Game.bar(fat / maxf(data.fat, 0.01)),
		"ちょうどいい: 中 %d〜%d%%" % [int(data.ideal.x / 1.2 * 100), int(data.ideal.y / 1.2 * 100)],
	]
	return "\n".join(lines)
