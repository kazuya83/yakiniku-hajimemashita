extends Node
## ゲーム全体の状態（所持金・日数・評判・画質）

signal toast(text: String)
signal money_changed

var money := 30000
var day := 1
var reviews: Array[float] = []
var quality := "mid"
var font: Font = preload("res://fonts/NotoSansJP.ttf")
var main: Node3D
var hud: CanvasLayer

# 在庫：部位 → [{"n": 枚数, "exp": 何日目まで使えるか}]（古い順）
var stock := {}
var orders := {}        # 発注済み（明日届く）：部位 → 箱数
var clean_plates := 12
var dirty_plates := 0
var clean_jugs := 8
var dirty_jugs := 0
var day_waste := 0

const BOX_PIECES := 20
const SHELF_DAYS := 3


func _ready() -> void:
	for c in MeatData.ORDER:
		stock[c] = [{"n": 16, "exp": SHELF_DAYS}]


func stock_count(c: String) -> int:
	var n := 0
	for lot in stock.get(c, []):
		n += lot.n
	return n


func stock_days_left(c: String) -> int:
	var lots: Array = stock.get(c, [])
	if lots.is_empty():
		return -1
	return lots[0].exp - day


func take_stock(c: String, n: int) -> bool:
	if stock_count(c) < n:
		return false
	var lots: Array = stock[c]
	while n > 0:
		var k := mini(n, lots[0].n)
		lots[0].n -= k
		n -= k
		if lots[0].n <= 0:
			lots.pop_front()
	return true


func add_stock(c: String, n: int) -> void:
	if not stock.has(c):
		stock[c] = []
	stock[c].append({"n": n, "exp": day + SHELF_DAYS - 1})


func box_cost(c: String) -> int:
	return int(MeatData.CUTS[c].price * 0.35 / 4.0 * BOX_PIECES / 10.0) * 10


## 朝：期限切れを捨てる。捨てた枚数を返す
func discard_expired() -> Dictionary:
	var out := {}
	for c in stock:
		var keep: Array = []
		for lot in stock[c]:
			if lot.exp < day:
				out[c] = out.get(c, 0) + lot.n
			else:
				keep.append(lot)
		stock[c] = keep
	return out


func add_money(v: int) -> void:
	money += v
	money_changed.emit()


func say(t: String) -> void:
	toast.emit(t)


func add_review(stars: float) -> void:
	reviews.append(stars)
	if reviews.size() > 50:
		reviews.pop_front()


func rating() -> float:
	if reviews.is_empty():
		return 3.0
	var s := 0.0
	for r in reviews:
		s += r
	return s / reviews.size()


static func bar(v: float, n: int = 10) -> String:
	var k := clampi(int(round(clampf(v, 0.0, 1.0) * n)), 0, n)
	return "■".repeat(k) + "□".repeat(n - k)


static func yen(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + "¥" + s + out
