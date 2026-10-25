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
