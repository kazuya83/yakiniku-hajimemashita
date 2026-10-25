class_name Person
extends Node3D
## 人の見た目と歩き。お客さんとアルバイトが使う
## assets/people/<look>.glb（3Dスキャン風のリアルな人）があればそれを使い、なければ簡単な形で作る

const CUSTOMER_LOOKS := ["man1", "woman1", "oldman", "student"]
const ANIM_FILES := {
	"sit": "res://assets/people/anim_sit.glb",
	"sit_f": "res://assets/people/anim_sit_f.glb",
	"sit_drink": "res://assets/people/anim_sit_drink.glb",
	"idle": "res://assets/people/anim_idle.glb",
}
const WOMEN := ["woman1", "staff_f"]

var model: Node3D
var head: MeshInstance3D
var arm: MeshInstance3D
var path: Array[Vector3] = []
var speed := 1.3
var seated := false
var look := ""          # 空ならお客さんの見た目からランダム
var real := false       # リアルな3Dモデルを使っているか
var _walk_t := 0.0
var _anim: AnimationPlayer
var _hand: HandRaise
var _cur := ""
static var _clips := {}


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
	var inst := scn.instantiate()
	model.add_child(inst)
	real = true
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hand = HandRaise.new()
	sk.add_child(_hand)
	_anim = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var lib := _anim.get_animation_library("")
	# 歩き（モデルに入っている）を "walk" に
	var names := lib.get_animation_list()
	if not names.is_empty() and not lib.has_animation("walk"):
		var w := lib.get_animation(names[0])
		w.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("walk", w)
	for k in ANIM_FILES:
		var a := _clip(k)
		if a:
			lib.add_animation(k, a)
	# 頭と腕は見えない目印だけ置く（ほかのスクリプトが位置を使う）
	head = MeshInstance3D.new()
	head.position.y = 1.66
	model.add_child(head)
	arm = MeshInstance3D.new()
	model.add_child(arm)
	_play("idle")
	return true


## 座る・立ち止まるの動き（1体のモデルで作ったものを、ほかの人にも使い回す）
static func _clip(k: String) -> Animation:
	if _clips.has(k):
		return _clips[k]
	var a: Animation = null
	if ResourceLoader.exists(ANIM_FILES[k]):
		var inst: Node = (load(ANIM_FILES[k]) as PackedScene).instantiate()
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var lib := ap.get_animation_library("")
		var src := lib.get_animation(lib.get_animation_list()[0])
		a = src.duplicate(true)
		# 体格の違う人に使うので、腰以外の骨の位置は動かさない
		for t in range(a.get_track_count() - 1, -1, -1):
			var tp := a.track_get_type(t)
			var bone := str(a.track_get_path(t)).get_slice(":", 1)
			if tp == Animation.TYPE_SCALE_3D or (tp == Animation.TYPE_POSITION_3D and bone != "Hips"):
				a.remove_track(t)
			elif tp == Animation.TYPE_POSITION_3D:
				# 腰は高さだけ使い、前後左右は椅子の真ん中に合わせる
				for kk in a.track_get_key_count(t):
					var v: Vector3 = a.track_get_key_value(t, kk)
					a.track_set_key_value(t, kk, Vector3(0, v.y, 0))
		a.loop_mode = Animation.LOOP_LINEAR
		inst.free()
	_clips[k] = a
	return a


func _play(n: String) -> void:
	if _anim == null or _cur == n:
		return
	if not _anim.has_animation(n) and n.begins_with("sit"):
		n = "sit"
	if not _anim.has_animation(n):
		n = "walk" if not n.begins_with("sit") else "idle"
		if not _anim.has_animation(n):
			return
	_cur = n
	_anim.play(n, 0.25)


func _process(_dt: float) -> void:
	if real and not seated and path.is_empty():
		_play("idle")


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
		var k := "sit_f" if WOMEN.has(look) else "sit"
		if randf() < 0.35:
			k = "sit_drink"
		_play(k)
		model.position = SIT_OFFSET + Vector3(0, seat_h - 0.45, 0)
		return
	model.position.y = height


const SIT_OFFSET := Vector3(0, 0, 0)


func stand() -> void:
	seated = false
	model.position = Vector3.ZERO
	raise_hand(false)
	if real:
		_anim.speed_scale = 1.0
		_play("idle")


func raise_hand(on: bool) -> void:
	if _hand:
		_hand.on = on
		return
	if arm:
		arm.rotation.x = -2.6 if on else 0.0
		arm.position.y = 1.45 if on else 1.15
