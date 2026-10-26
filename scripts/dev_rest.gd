extends Node3D
## 開発用：モデルを休みの姿勢のまま並べ、骨の位置に印を付けて撮る
var out := "/tmp"
var frame := 0
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.4, 0.4, 0.42)
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var looks := ["man1", "woman1", "oldman", "student", "staff_f", "staff_m"]
	var dot := StandardMaterial3D.new()
	dot.albedo_color = Color(1, 0, 0)
	dot.no_depth_test = true
	dot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in looks.size():
		var inst: Node3D = load("res://assets/people/%s.glb" % looks[i]).instantiate()
		inst.position = Vector3(-2.5 + i * 1.0, 0, 0)
		add_child(inst)
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			ap.stop()
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		sk.reset_bone_poses()
		for b in sk.get_bone_count():
			var m := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 2.0
			sm.height = 4.0
			m.mesh = sm
			m.material_override = dot
			m.position = sk.get_bone_global_rest(b).origin
			sk.add_child(m)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 4.2)
	add_child(cam)
	cam.current = true
func _process(_dt: float) -> void:
	frame += 1
	if frame == 10:
		get_viewport().get_texture().get_image().save_png(out + "/rest.png")
		get_tree().quit()
