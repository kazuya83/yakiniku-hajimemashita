class_name CuttingBoard
extends Node3D
## まな板（自家カット）。冷蔵庫の塊肉を、E長押しで1枚ずつ切り分ける

const SHADER := preload("res://shaders/meat.gdshader")
const SLICE_TIME := 0.45

var cut := ""
var left := 0          # 今まな板にある塊の残り枚数
var _t := 0.0
var _block: MeshInstance3D
var _mat: ShaderMaterial
var _knife: Node3D
var _chop := 0.0


func _ready() -> void:
	Build.box(self, Vector3(0.5, 0.025, 0.35), Vector3(0, 0.0125, 0), Build.mat(Color(0.92, 0.9, 0.84), 0.6))
	_block = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.08, 0.12)
	_block.mesh = bm
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_block.material_override = _mat
	_block.position = Vector3(-0.05, 0.065, 0)
	_block.visible = false
	add_child(_block)
	_knife = Node3D.new()
	_knife.position = Vector3(0.08, 0.12, 0)
	_knife.visible = false
	add_child(_knife)
	Build.box(_knife, Vector3(0.012, 0.045, 0.22), Vector3(0, 0, -0.02), Build.mat(Color(0.85, 0.86, 0.88), 0.2, 1.0), false)
	Build.box(_knife, Vector3(0.018, 0.028, 0.11), Vector3(0, 0.005, 0.14), Build.mat(Color(0.12, 0.08, 0.05), 0.6), false)


func _process(dt: float) -> void:
	_chop = maxf(_chop - dt, 0.0)
	_knife.position.y = 0.12 - (sin((1.0 - _chop / 0.2) * PI) * 0.05 if _chop > 0.0 else 0.0)


func _cuts_with_blocks() -> Array:
	return MeatData.menu().filter(func(c): return Game.blocks.get(c, 0) > 0)


func get_hint(p: Player) -> String:
	if not Game.has("selfcut"):
		return "まな板（自家カットは店が成長すると解放）"
	var t := "まな板（自家カット）"
	if left > 0:
		t += "\n%sの塊　あと%d枚分\nE長押し: 切る" % [MeatData.CUTS[cut].name, left]
		return t
	var cs := _cuts_with_blocks()
	if cs.is_empty():
		return t + "\n塊肉がない（タブレットで「塊」を発注）"
	if cut == "" or not cs.has(cut):
		cut = cs[0]
	t += "\n%sの塊（冷蔵庫に%d個）　ホイール: 部位を変える\nE長押し: 塊を出して切る" % [MeatData.CUTS[cut].name, Game.blocks[cut]]
	return t


func scroll(_p: Player, d: int) -> void:
	if left > 0:
		return
	var cs := _cuts_with_blocks()
	if cs.is_empty():
		return
	var i := cs.find(cut)
	cut = cs[wrapi(i + d, 0, cs.size())]


func hold_use(p: Player, dt: float) -> void:
	if not Game.has("selfcut") or p.held:
		return
	if left <= 0:
		if cut == "" or Game.blocks.get(cut, 0) <= 0:
			return
		Game.blocks[cut] -= 1
		left = Game.BLOCK_SLICES
		var d: Dictionary = MeatData.CUTS[cut]
		_mat.set_shader_parameter("raw_color", d.color)
		_mat.set_shader_parameter("fat_color", d.fat_color)
		_mat.set_shader_parameter("marbling", d.marbling)
		_mat.set_shader_parameter("seed", randf() * 100.0)
		_t = 0.0
	_block.visible = true
	_knife.visible = true
	_t += dt
	if _t >= SLICE_TIME:
		_t = 0.0
		_chop = 0.2
		left -= 1
		_block.scale.x = maxf(float(left) / Game.BLOCK_SLICES, 0.05)
		_block.position.x = -0.05 - (1.0 - _block.scale.x) * 0.11
		if left % 4 == 0:
			Game.add_stock(cut, 4)
		if left <= 0:
			_block.visible = false
			_knife.visible = false
			Game.say("%sを%d枚切った！冷蔵庫に入れた" % [MeatData.CUTS[cut].name, Game.BLOCK_SLICES])


func get_info(_p: Player) -> String:
	if left > 0:
		return "切った枚数 %d / %d" % [Game.BLOCK_SLICES - left, Game.BLOCK_SLICES]
	return ""
