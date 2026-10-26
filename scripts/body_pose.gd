class_name BodyPose
extends SkeletonModifier3D
## リアルな人の立ち姿・座り姿・手を挙げる・お盆を持つなどの姿勢を骨の向きで直接決める
## モデルごとに休みの姿勢（腕の上げ方など）がばらばらなので、動きの使い回しではなく
## 「上腕は真下」「太ももは前」のように体の向きで目標を決め、どのモデルでも同じ形にする
## 向きは人から見て +Z が前、+Y が上、+X が左

var body := 0.0          # 0 = 歩きの動きのまま、1 = ここで決めた姿勢
var seated := false
var seat_h := 0.45       # 座面の高さ（m）
var hand := false        # 右手を挙げる
var carry := false       # 両手でお盆を持つ
var work := false        # 立っているとき手を前に出して作業している
var eating := false      # 座っているとき、ときどき箸を口に運ぶ
var person: Node3D

const PALM_TWIST := {}

var _w_body := 0.0
var _w_hand := 0.0
var _w_carry := 0.0
var _w_sit := 0.0
var _w_eat := 0.0
var _t := 0.0
var _eat_next := 3.0
var _eat_t := -1.0
var _seed := 0.0

# 休みの姿勢の情報（モデルごとに一度だけ計算）
var _ready_rig := false
var _n := 0
var _parent: Array[int] = []
var _rest_local: Array[Quaternion] = []
var _rest_g: Array[Quaternion] = []
var _rest_dir := {}      # bone -> 子の骨へ向かう向き
var _rest_ref := {}      # bone -> ねじれの基準
var _bone := {}          # 名前 -> 番号
var _hips_rest := Vector3.ZERO
var _last_us := 0


func _ready() -> void:
	_seed = randf() * 100.0
	_eat_next = randf_range(1.0, 5.0)


func _setup(sk: Skeleton3D) -> void:
	_ready_rig = true
	_n = sk.get_bone_count()
	var gpos: Array[Vector3] = []
	for b in _n:
		_bone[sk.get_bone_name(b)] = b
		_parent.append(sk.get_bone_parent(b))
		var q := sk.get_bone_rest(b).basis.get_rotation_quaternion()
		_rest_local.append(q)
		_rest_g.append(_rest_g[_parent[b]] * q if _parent[b] >= 0 else q)
		gpos.append(sk.get_bone_global_rest(b).origin)
	_hips_rest = sk.get_bone_rest(_b("Hips")).origin
	var chain := {
		"Spine02": "Spine01", "Spine01": "Spine", "Spine": "neck", "neck": "Head", "Head": "head_end",
		"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand",
		"RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
		"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase",
		"RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase",
	}
	for k in chain:
		if _bone.has(k) and _bone.has(chain[k]):
			_rest_dir[k] = (gpos[_bone[chain[k]]] - gpos[_bone[k]]).normalized()
	# 顔の正面
	if _bone.has("Head") and _bone.has("headfront"):
		_rest_ref["Head"] = gpos[_bone["headfront"]] - gpos[_bone["Head"]]
	# 腕のねじれ：ひじの曲がる向き（力こぶ側＝手のひら側）を基準にする
	for s in ["Left", "Right"]:
		var a: String = s + "Arm"
		var f: String = s + "ForeArm"
		if not (_rest_dir.has(a) and _rest_dir.has(f)):
			continue
		var ua: Vector3 = _rest_dir[a]
		var fa: Vector3 = _rest_dir[f]
		var bend := fa - ua * fa.dot(ua)
		_rest_ref[a] = bend if bend.length() > 0.15 else Vector3.UP
		# 元のモデルの手のひらの向き（どのモデルも、下向きから前腕の軸まわりに 90° 回した向きだった）
		var lk := str(person.get("look")) if person else ""
		var tw: float = PALM_TWIST.get(lk, 90.0)
		for a2 in OS.get_cmdline_user_args():
			if a2.begins_with("--twist="):
				tw = float(a2.substr(8))
		var base := Vector3.DOWN - fa * Vector3.DOWN.dot(fa)
		_rest_ref[f] = base.rotated(fa, deg_to_rad(tw * (1.0 if s == "Left" else -1.0)))


func _b(nm: String) -> int:
	return _bone.get(nm, -1)


static func _frame(dir: Vector3, ref: Vector3) -> Quaternion:
	var x := dir.normalized()
	var z := ref - x * ref.dot(x)
	if z.length() < 0.001:
		z = Vector3.FORWARD if absf(x.y) > 0.9 else Vector3.UP
		z = z - x * z.dot(x)
	z = z.normalized()
	var y := z.cross(x)
	return Basis(x, y, z).get_rotation_quaternion()


## 今の状態から、骨ごとの目標 [向き, ねじれの基準 or null] を作る
func _pose() -> Dictionary:
	var t := _t + _seed
	var breath := sin(t * 1.6) * 0.012
	var p := {}
	var sit := _w_sit
	# 背骨と頭（座ると少し前かがみ・少しうつむく）
	var lean := lerpf(0.02, 0.1, sit) + breath
	p["Spine02"] = [Vector3(0, 1, lean), null]
	p["Spine01"] = [Vector3(0, 1, lean), null]
	p["Spine"] = [Vector3(0, 1, lean * 0.5), null]
	# 頭は元の顔の向きを基準に、ゆっくり見回す・座ると少しうつむく
	var yaw := sin(t * 0.37) * 0.2 + sin(t * 0.13) * 0.15
	var nod := lerpf(0.0, 0.2, sit) + sin(t * 0.5) * 0.03
	p["Head"] = [null, Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, nod)]
	for i in 2:
		var side := "Left" if i == 0 else "Right"
		var s := 1.0 if i == 0 else -1.0
		p[side + "Shoulder"] = [Vector3(s, 0.0, -0.2), null]
		# 腕：立つ＝体の横に下ろす、座る＝テーブルや膝に手を置く
		var arm_stand := Vector3(s * 0.14, -1, 0.04)
		var fore_stand := Vector3(s * 0.06, -1, 0.22)
		var palm_stand := Vector3(-s, 0, 0.35)
		if work:
			arm_stand = Vector3(s * 0.12, -1, 0.25)
			fore_stand = Vector3(-s * 0.2, -0.25, 1)
			palm_stand = Vector3(0, -1, 0)
		var arm_sit := Vector3(s * 0.12, -1, 0.3)
		var fore_sit := Vector3(-s * 0.35, -0.35, 1)
		var palm_sit := Vector3(0, -1, 0)
		var ad := arm_stand.lerp(arm_sit, sit)
		var fd := fore_stand.lerp(fore_sit, sit)
		var pr := palm_stand.lerp(palm_sit, sit)
		# お盆を持つ（ひじを曲げて手のひらを上に）
		ad = ad.lerp(Vector3(s * 0.15, -1, 0.15), _w_carry)
		fd = fd.lerp(Vector3(-s * 0.15, 0.05, 1), _w_carry)
		pr = pr.lerp(Vector3(0, 1, 0), _w_carry)
		if i == 1:
			# 箸を口へ運ぶ
			ad = ad.lerp(Vector3(-0.15, -0.85, 0.6), _w_eat)
			fd = fd.lerp(Vector3(0.45, 0.85, 0.35), _w_eat)
			pr = pr.lerp(Vector3(0.2, 0, -1), _w_eat)
			# 手を挙げる「すみませーん」
			ad = ad.lerp(Vector3(-0.3, 1, 0.15), _w_hand)
			fd = fd.lerp(Vector3(-0.1, 1, 0.2), _w_hand)
			pr = pr.lerp(Vector3(0, 0, 1), _w_hand)
		p[side + "Arm"] = [ad, fd]
		p[side + "ForeArm"] = [fd, pr]
		# 脚：立つ＝まっすぐ、座る＝太ももを前・すねを下
		var shin := Vector3(s * 0.04, -1, lerpf(0.1, 0.35, clampf((seat_h - 0.45) * 4.0, 0, 1)))
		p[side + "UpLeg"] = [Vector3(s * 0.06, -1, 0.0).lerp(Vector3(s * 0.12, -0.08, 1), sit), null]
		p[side + "Leg"] = [Vector3(0, -1, -0.03).lerp(shin, sit), null]
		p[side + "Foot"] = [Vector3(s * 0.15, -0.75, 0.6).lerp(Vector3(s * 0.1, -0.5, 1), sit), null]
	return p


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _ready_rig:
		_setup(sk)
	# 時間（モディファイアは毎フレーム呼ばれる）
	var now := Time.get_ticks_usec()
	var dt := 0.016 if _last_us == 0 else clampf((now - _last_us) / 1e6, 0.0, 0.1)
	_last_us = now
	_t += dt
	_w_body = move_toward(_w_body, body, dt * 3.0)
	_w_sit = move_toward(_w_sit, 1.0 if seated else 0.0, dt * 2.0)
	_w_hand = move_toward(_w_hand, 1.0 if hand else 0.0, dt * 3.0)
	_w_carry = move_toward(_w_carry, 1.0 if carry else 0.0, dt * 4.0)
	_update_eat(dt)
	var w_arm := maxf(_w_body, maxf(_w_carry, _w_hand))
	var pose := _pose()
	var blended: Array[Quaternion] = []
	blended.resize(_n)
	for b in _n:
		var nm := sk.get_bone_name(b)
		var pb := _parent[b]
		var gp: Quaternion = blended[pb] if pb >= 0 else Quaternion()
		var cur := sk.get_bone_pose_rotation(b)
		var is_arm := nm.contains("Arm") or nm.contains("Hand") or nm.contains("Shoulder")
		var w := w_arm if is_arm else _w_body
		var target_local := _rest_local[b]
		if pose.has(nm) and pose[nm][0] == null:
			# 休みの姿勢からの回転で決める骨（頭）
			target_local = gp.inverse() * (pose[nm][1] * _rest_g[b])
		elif pose.has(nm) and _rest_dir.has(nm):
			var d: Vector3 = pose[nm][0]
			var r = pose[nm][1]
			var rot: Quaternion
			if r == null or not _rest_ref.has(nm):
				rot = Quaternion(_rest_dir[nm], d.normalized())
			else:
				rot = _frame(d, r) * _frame(_rest_dir[nm], _rest_ref[nm]).inverse()
			target_local = gp.inverse() * (rot * _rest_g[b])
		elif pb >= 0 and w < 1.0:
			# 目標のない骨：休みの姿勢へ寄せる
			target_local = _rest_local[b]
		var q := cur.slerp(target_local.normalized(), w) if w > 0.0 else cur
		blended[b] = gp * q
		sk.set_bone_pose_rotation(b, q)
	# 腰の位置：座るときは座面の上、少し後ろへ
	var hb := _b("Hips")
	if hb >= 0 and _w_body > 0.0:
		var target := _hips_rest
		if person and _w_sit > 0.0:
			var world := person.global_transform * Vector3(0, seat_h + 0.1, 0.12)
			var local := sk.global_transform.affine_inverse() * world
			target = _hips_rest.lerp(Vector3(_hips_rest.x, local.y, local.z), _w_sit)
		sk.set_bone_pose_position(hb, sk.get_bone_pose_position(hb).lerp(target, _w_body))


func _update_eat(dt: float) -> void:
	if not (eating and seated and not hand):
		_w_eat = move_toward(_w_eat, 0.0, dt * 2.0)
		_eat_t = -1.0
		return
	if _eat_t < 0.0:
		_eat_next -= dt
		if _eat_next <= 0.0:
			_eat_t = 0.0
		_w_eat = move_toward(_w_eat, 0.0, dt * 2.0)
		return
	_eat_t += dt
	# 0.7秒で口へ、0.6秒止めて、0.7秒で戻す
	if _eat_t < 0.7:
		_w_eat = smoothstep(0.0, 0.7, _eat_t)
	elif _eat_t < 1.3:
		_w_eat = 1.0
	elif _eat_t < 2.0:
		_w_eat = 1.0 - smoothstep(1.3, 2.0, _eat_t)
	else:
		_w_eat = 0.0
		_eat_t = -1.0
		_eat_next = randf_range(3.0, 8.0)
