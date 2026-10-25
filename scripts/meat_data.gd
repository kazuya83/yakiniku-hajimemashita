class_name MeatData
## 部位ごとの数値と、肉の形のメッシュ生成

# w/d/t はメートル。sear_k は表面の焼ける速さ、fat は脂の量、ideal は中の火の通りのちょうどいい範囲
const CUTS := {
	"tan": {
		"name": "タン塩", "price": 900, "w": 0.085, "d": 0.085, "t": 0.005, "exp": 2.0,
		"sear_k": 1.35, "fat": 0.25, "color": Color(0.80, 0.50, 0.50), "fat_color": Color(0.93, 0.85, 0.82),
		"marbling": 0.12, "ideal": Vector2(0.55, 0.95),
	},
	"karubi": {
		"name": "カルビ", "price": 980, "w": 0.11, "d": 0.06, "t": 0.008, "exp": 4.0,
		"sear_k": 1.0, "fat": 0.95, "color": Color(0.72, 0.18, 0.18), "fat_color": Color(0.96, 0.88, 0.84),
		"marbling": 0.65, "ideal": Vector2(0.6, 1.0),
	},
	"rosu": {
		"name": "ロース", "price": 1080, "w": 0.10, "d": 0.072, "t": 0.009, "exp": 2.4,
		"sear_k": 0.95, "fat": 0.5, "color": Color(0.70, 0.17, 0.19), "fat_color": Color(0.95, 0.86, 0.82),
		"marbling": 0.38, "ideal": Vector2(0.5, 0.85),
	},
	"harami": {
		"name": "ハラミ", "price": 1180, "w": 0.13, "d": 0.045, "t": 0.012, "exp": 3.0,
		"sear_k": 0.9, "fat": 0.5, "color": Color(0.55, 0.11, 0.12), "fat_color": Color(0.90, 0.78, 0.74),
		"marbling": 0.22, "ideal": Vector2(0.5, 0.9),
	},
	"jo_tan": {
		"name": "上タン塩", "price": 1580, "w": 0.09, "d": 0.09, "t": 0.009, "exp": 2.2,
		"sear_k": 1.15, "fat": 0.35, "color": Color(0.84, 0.55, 0.56), "fat_color": Color(0.95, 0.88, 0.86),
		"marbling": 0.3, "ideal": Vector2(0.5, 0.85),
	},
	"tokujo_karubi": {
		"name": "特上カルビ", "price": 1880, "w": 0.12, "d": 0.07, "t": 0.009, "exp": 4.2,
		"sear_k": 1.05, "fat": 1.0, "color": Color(0.78, 0.24, 0.25), "fat_color": Color(0.97, 0.92, 0.88),
		"marbling": 0.9, "ideal": Vector2(0.45, 0.8),
	},
}

const ORDER := ["tan", "karubi", "rosu", "harami", "jo_tan", "tokujo_karubi"]
const BASE := ["tan", "karubi", "rosu", "harami"]
const PREMIUM := ["jo_tan", "tokujo_karubi"]


## その部位がメニューにあるか（高級部位は成長で解放）
static func on_menu(c: String) -> bool:
	return not PREMIUM.has(c) or Game.has("premium")


static func menu() -> Array:
	return ORDER.filter(func(c): return on_menu(c))

const DRINKS := {
	"beer": {"name": "生ビール", "price": 550, "color": Color(0.95, 0.62, 0.12, 0.85)},
	"highball": {"name": "ハイボール", "price": 480, "color": Color(0.95, 0.85, 0.55, 0.55)},
	"oolong": {"name": "ウーロン茶", "price": 320, "color": Color(0.55, 0.28, 0.08, 0.85)},
}
const DRINK_ORDER := ["beer", "highball", "oolong"]


static func item_name(k: String) -> String:
	if CUTS.has(k):
		return CUTS[k].name
	return DRINKS[k].name


static func item_price(k: String) -> int:
	if CUTS.has(k):
		return CUTS[k].price
	return DRINKS[k].price


static func is_drink(k: String) -> bool:
	return DRINKS.has(k)


static func build_mesh(d: Dictionary, seed: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed * 1000.0)
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var n := 32
	var pts: Array[Vector2] = []
	var e: float = d.exp
	for i in n:
		var a := TAU * i / n
		var c := cos(a)
		var s := sin(a)
		var x: float = signf(c) * pow(absf(c), 2.0 / e) * d.w * 0.5
		var z: float = signf(s) * pow(absf(s), 2.0 / e) * d.d * 0.5
		var k := 1.0 + 0.06 * sin(3.0 * a + ph1) + 0.035 * sin(7.0 * a + ph2)
		pts.append(Vector2(x * k, z * k))
	# 上下の面は同心円状に細かく割り、厚みにわずかなムラをつける（焼き縮み・反りを頂点で表すため）
	var ht: float = d.t * 0.5
	var rings := 6
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 28.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		var grid: Array = []
		for r in rings + 1:
			var row: Array[Vector3] = []
			var f := float(r) / rings
			for i in n:
				var p := pts[i] * f
				# 縁は少し丸める
				var edge := smoothstep(0.82, 1.0, f)
				var y := ht * (1.0 + 0.14 * noise.get_noise_2d(p.x, p.y)) * (1.0 - 0.35 * edge * edge)
				row.append(Vector3(p.x * (1.0 - 0.02 * edge), y * side, p.y * (1.0 - 0.02 * edge)))
			grid.append(row)
		for r in rings:
			for i in n:
				var j := (i + 1) % n
				var a0: Vector3 = grid[r][i]
				var a1: Vector3 = grid[r][j]
				var b0: Vector3 = grid[r + 1][i]
				var b1: Vector3 = grid[r + 1][j]
				var fa := float(r) / rings
				var fb := float(r + 1) / rings
				if side > 0:
					_v(st, a0, fa); _v(st, b0, fb); _v(st, b1, fb)
					_v(st, a0, fa); _v(st, b1, fb); _v(st, a1, fa)
				else:
					_v(st, a0, fa); _v(st, b1, fb); _v(st, b0, fb)
					_v(st, a0, fa); _v(st, a1, fa); _v(st, b1, fb)
	# 側面
	for i in n:
		var p0 := pts[i] * 0.98
		var p1 := pts[(i + 1) % n] * 0.98
		var h0 := ht * 0.65
		_v(st, Vector3(p0.x, h0, p0.y), 1.0); _v(st, Vector3(p0.x, -h0, p0.y), 1.0); _v(st, Vector3(p1.x, h0, p1.y), 1.0)
		_v(st, Vector3(p1.x, h0, p1.y), 1.0); _v(st, Vector3(p0.x, -h0, p0.y), 1.0); _v(st, Vector3(p1.x, -h0, p1.y), 1.0)
	st.generate_normals()
	return st.commit()


## 頂点。UV2.x に中心からの距離（0〜1）を入れて、焼くと縁が反るのに使う
static func _v(st: SurfaceTool, v: Vector3, f: float) -> void:
	st.set_uv(Vector2(v.x, v.z) * 5.0)
	st.set_uv2(Vector2(f, 0.0))
	st.add_vertex(v)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3) -> void:
	for v in [a, b, c]:
		st.set_normal(nrm)
		st.set_uv(Vector2(v.x, v.z) * 5.0)
		st.add_vertex(v)
