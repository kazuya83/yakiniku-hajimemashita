extends Node3D
## 開発用：リアルな人の座り・立ち・歩き・手を挙げるを並べて撮る
## godot --path . res://scenes/dev_pose.tscn -- --out=<dir>

var out := "/tmp"
var ps: Array = []
var frame := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var root := self
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.4, 0.4, 0.42)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	root.add_child(sun)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_m.mesh = pm
	root.add_child(floor_m)
	var looks := ["man1", "woman1", "oldman", "student", "staff_f", "staff_m"]
	for i in looks.size():
		var p := Person.new()
		p.look = looks[i]
		p.position = Vector3(-3.0 + i * 1.2, 0, 0)
		root.add_child(p)
		ps.append(p)
		# 椅子（店と同じ高さ 0.45）
		var st := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.42, 0.45, 0.42)
		st.mesh = bm
		st.position = p.position + Vector3(0, 0.225, 0)
		root.add_child(st)
	var meat_mode := OS.get_cmdline_user_args().has("--meat")
	if meat_mode:
		for i in MeatData.ORDER.size():
			for j in 3:
				var me := Meat.new().setup(MeatData.ORDER[i])
				add_child(me)
				me.position = Vector3(-0.4 + i * 0.16, 0.6, -0.15 + j * 0.15)
				me.sear = [[0.0, 0.0], [0.5, 0.5], [0.9, 0.9]][j]
				me.core = [0.0, 0.5, 0.85][j]
				me._update_mat()
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 1.4, 0.3)
		lamp.light_color = Color(1.0, 0.8, 0.6)
		lamp.light_energy = 1.5
		add_child(lamp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 4.2)
	root.add_child(cam)
	cam.current = true
	if meat_mode:
		cam.position = Vector3(0, 1.15, 0.55)
		cam.look_at.call_deferred(Vector3(0, 0.6, 0))
	else:
		cam.look_at.call_deferred(Vector3(0, 0.7, 0))


func _process(_dt: float) -> void:
	frame += 1
	if frame == 2:
		for i in ps.size():
			if i < 4:
				ps[i].sit(0.0, -0.38)
		ps[4].raise_hand(true)
		ps[5].path.append(Vector3(30, 0, 0))
	if frame > 2 and frame < 200:
		ps[5].walk(0.0)
	if frame == 90:
		get_viewport().get_texture().get_image().save_png(out + "/front.png")
		for p in ps:
			p.rotation.y += PI / 2
	if frame == 130:
		get_viewport().get_texture().get_image().save_png(out + "/side.png")
		get_tree().quit()
