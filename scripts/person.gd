class_name Person
extends Node3D
## 人の見た目と歩き。お客さんとアルバイトが使う
## assets/people/<look>.glb（3Dスキャン風のリアルな人）があればそれを使い、なければ簡単な形で作る

const CUSTOMER_LOOKS := ["man1", "woman1", "oldman", "student"]

var model: Node3D
var head: MeshInstance3D
var arm: MeshInstance3D
var path: Array[Vector3] = []
var speed := 1.3
var seated := false
var look := ""          # 空ならお客さんの見た目からランダム
var real := false       # リアルな3Dモデルを使っているか
var eating := false     # 座って食べている（ときどき箸を口へ運ぶ）
var _walk_t := 0.0
var _anim: AnimationPlayer
var pose: BodyPose
var _cur := ""


func _ready() -> void:
	model = Node3D.new()
	add_child(model)
	if look == "":
		look = CUSTOMER_LOOKS.pick_random()
	if _load_real():
		return
	var shirt := Build.mat(Color.from_hsv(randf(), randf_range(0.2, 0.6), randf_range(0.35, 0.8)), 0.8)
	var skin := Build.mat(Color(0.93, 0.78, 0.65).darkened(randf() * 0.25), 0.6)
	var hair := Build.mat(Color(0.06, 0.05, 0.04).lightened(randf() * 0.25), 0.7)
	var legs := Build.mat(Color.from_hsv(randf(), 0.2, randf_range(0.12, 0.3)), 0.8)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 0.75
	body.mesh = cap
	body.material_override = shirt
	body.position.y = 1.15
	model.add_child(body)
	for s in [-0.09, 0.09]:
		Build.box(model, Vector3(0.13, 0.8, 0.14), Vector3(s, 0.4, 0), legs, false)
	arm = Build.box(model, Vector3(0.09, 0.5, 0.09), Vector3(0.24, 1.15, 0), shirt, false)
	Build.box(model, Vector3(0.09, 0.5, 0.09), Vector3(-0.24, 1.15, 0), shirt, false)
	head = Build.sphere(model, 0.12, Vector3(0, 1.66, 0), skin)
	var h := Build.sphere(head, 0.125, Vector3(0, 0.035, 0.015), hair)
	h.scale = Vector3(1, 0.8, 1)


func _load_real() -> bool:
	var f := "res://assets/people/%s.glb" % look
	if not ResourceLoader.exists(f):
		return false
	var scn: PackedScene = load(f)
	var inst: Node3D = scn.instantiate()
	# 3Dモデルは +Z が正面。このゲームの人は -Z を正面にしているので向きを合わせる
	inst.rotation.y = PI
	model.add_child(inst)
	real = true
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pose = BodyPose.new()
	pose.person = self
	sk.add_child(pose)
	_anim = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var lib := _anim.get_animation_library("")
	# 歩き（モデルに入っている）を "walk" に
	var names := lib.get_animation_list()
	if not names.is_empty() and not lib.has_animation("walk"):
		var w := lib.get_animation(names[0])
		w.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("walk", w)
	# 頭と腕は見えない目印だけ置く（ほかのスクリプトが位置を使う）
	head = MeshInstance3D.new()
	head.position.y = 1.66
	model.add_child(head)
	arm = MeshInstance3D.new()
	model.add_child(arm)
	_play("idle")
	return true


## 歩きだけはモデルに入っている動き。立ち止まる・座るなどは BodyPose が骨の向きで作る
func _play(n: String) -> void:
	if _anim == null or _cur == n:
		return
	_cur = n
	pose.body = 0.0 if n == "walk" else 1.0
	if n == "walk":
		_anim.play("walk", 0.25)


func _process(_dt: float) -> void:
	if real and not seated and path.is_empty():
		_play("idle")
	if pose:
		pose.eating = eating


## 歩き終わったら true
func walk(dt: float) -> bool:
	if path.is_empty():
		return true
	if real:
		_play("walk")
		_anim.speed_scale = speed / 1.2
	var target: Vector3 = path[0]
	var to := target - position
	to.y = 0
	var step := speed * dt
	if to.length() <= step:
		position = Vector3(target.x, 0, target.z)
		path.pop_front()
	else:
		var d := to.normalized()
		position += d * step
		rotation.y = atan2(-d.x, -d.z)
		if not real:
			_walk_t += dt * 9.0
			model.position.y = absf(sin(_walk_t)) * 0.03
	return path.is_empty()


## seat_h は座面の高さ（リアルな人の座る動きは 0.45m の椅子に合わせてある）
func sit(face_yaw: float, height: float = -0.2, seat_h: float = 0.45) -> void:
	seated = true
	rotation.y = face_yaw
	if real:
		_anim.speed_scale = 1.0
		pose.seated = true
		pose.seat_h = seat_h
		_play("sit")
		return
	model.position.y = height


func stand() -> void:
	seated = false
	eating = false
	model.position = Vector3.ZERO
	raise_hand(false)
	if real:
		_anim.speed_scale = 1.0
		pose.seated = false
		pose.eating = false
		_play("idle")


func raise_hand(on: bool) -> void:
	if pose:
		pose.hand = on
		return
	if arm:
		arm.rotation.x = -2.6 if on else 0.0
		arm.position.y = 1.45 if on else 1.15
