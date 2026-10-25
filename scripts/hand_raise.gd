class_name HandRaise
extends SkeletonModifier3D
## リアルな人の右手を挙げる（「すみませーん」の合図）

var on := false
var _k := 0.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_k = move_toward(_k, 1.0 if on else 0.0, 0.08)
	if _k <= 0.0:
		return
	var b := sk.find_bone("RightArm")
	if b < 0:
		return
	# 上腕を体の外側から真上に向ける（ボーンの向きはスケルトン空間で計算）
	var parent := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var g := sk.get_bone_global_pose(b)
	var cur_dir := (g.basis * Vector3.UP).normalized()
	var up := Vector3.UP
	var q := Quaternion(cur_dir, up) if cur_dir.dot(up) < 0.999 else Quaternion()
	var target := Basis(Quaternion().slerp(q, _k * 0.95)) * g.basis
	var local := pg.basis.inverse() * target
	sk.set_bone_pose_rotation(b, local.get_rotation_quaternion())
