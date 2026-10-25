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
	var inst: Node3D = scn.instantiate()
	# 3Dモデルは +Z が正面。このゲームの人は -Z を正面にしているので向きを合わせる
	inst.rotation.y = PI
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
		var a := _clip(k, sk, look)
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


## 座る・立ち止まるの動き（1体のモデルで作ったものを、骨の向きの違うほかの人に合わせ直して使う）
static func _clip(k: String, sk: Skeleton3D, key: String) -> Animation:
	var ck := k + "@" + key
	if _clips.has(ck):
		return _clips[ck]
	var a: Animation = null
	if ResourceLoader.exists(ANIM_FILES[k]):
		var inst: Node = (load(ANIM_FILES[k]) as PackedScene).instantiate()
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var src_sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var lib := ap.get_animation_library("")
		var src := lib.get_animation(lib.get_animation_list()[0])
		a = _retarget(src, src_sk, sk)
		inst.free()
	_clips[ck] = a
	return a


## 元の動きを「休みの姿勢からどれだけ回したか」に直し、相手の休みの姿勢に当てはめる
static func _retarget(src: Animation, ssk: Skeleton3D, tsk: Skeleton3D) -> Animation:
	var rot_tr := {}
	var hips_pos := -1
	var track_prefix := ""
	for t in src.get_track_count():
		var path := str(src.track_get_path(t))
		var bone := path.get_slice(":", 1)
		if track_prefix == "":
			track_prefix = path.get_slice(":", 0)
		if src.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot_tr[bone] = t
		elif src.track_get_type(t) == Animation.TYPE_POSITION_3D and bone == "Hips":
			hips_pos = t
	# 時間は腰の回転のキーに合わせる
	var times: Array[float] = []
	var ref: int = rot_tr.get("Hips", rot_tr.values()[0])
	for i in src.track_get_key_count(ref):
		times.append(src.track_get_key_time(ref, i))
	var n := tsk.get_bone_count()
	# 休みの姿勢（スケルトン全体から見た向き）
	var srest := {}
	var trest: Array[Quaternion] = []
	for b in n:
		var nm := tsk.get_bone_name(b)
		var tp := tsk.get_bone_parent(b)
		var tq := tsk.get_bone_rest(b).basis.get_rotation_quaternion()
		trest.append(trest[tp] * tq if tp >= 0 else tq)
	for b in ssk.get_bone_count():
		var sp := ssk.get_bone_parent(b)
		var sq := ssk.get_bone_rest(b).basis.get_rotation_quaternion()
		srest[ssk.get_bone_name(b)] = (srest[ssk.get_bone_name(sp)] * sq) if sp >= 0 else sq
	var a := Animation.new()
	a.length = src.length
	a.loop_mode = Animation.LOOP_LINEAR
	var out := {}
	for b in n:
		var tr := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tr, NodePath("%s:%s" % [track_prefix, tsk.get_bone_name(b)]))
		out[b] = tr
	for time in times:
		var sglob := {}
		var tglob: Array[Quaternion] = []
		tglob.resize(n)
		for b in ssk.get_bone_count():
			var nm := ssk.get_bone_name(b)
			var sp := ssk.get_bone_parent(b)
			var q: Quaternion = src.rotation_track_interpolate(rot_tr[nm], time) if rot_tr.has(nm) else ssk.get_bone_rest(b).basis.get_rotation_quaternion()
			sglob[nm] = (sglob[ssk.get_bone_name(sp)] * q) if sp >= 0 else q
		for b in n:
			var nm := tsk.get_bone_name(b)
			var tp := tsk.get_bone_parent(b)
			var g: Quaternion = trest[b]
			if sglob.has(nm):
				g = (sglob[nm] * srest[nm].inverse()) * trest[b]
			tglob[b] = g
			var local := (tglob[tp].inverse() * g) if tp >= 0 else g
			a.rotation_track_insert_key(out[b], time, local.normalized())
	# 腰の高さ（体格に合わせて縮める）。前後左右は椅子の真ん中に合わせる
	if hips_pos >= 0:
		var sh := ssk.get_bone_rest(ssk.find_bone("Hips")).origin.y
		var th := tsk.get_bone_rest(tsk.find_bone("Hips")).origin.y
		var k := th / sh if sh > 0.001 else 1.0
		var pt := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(pt, src.track_get_path(hips_pos))
		for i in src.track_get_key_count(hips_pos):
			var v: Vector3 = src.track_get_key_value(hips_pos, i)
			a.position_track_insert_key(pt, src.track_get_key_time(hips_pos, i), Vector3(0, v.y * k, 0))
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
