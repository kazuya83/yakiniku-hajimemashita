extends Node
## ゲーム全体の状態（所持金・日数・評判・画質）

signal toast(text: String)
signal money_changed

var money := 300000
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
var fame := 0.0          # 店の格のポイント（お客さんの星の合計）
var unlocked := {}       # 買った成長要素：名前 → true
var blocks := {}         # 自家カット用の塊肉：部位 → 塊の数


# 店の格。ポイントがたまるとレベルが上がり、成長要素が買えるようになる
const LEVELS := [0, 30, 90, 200, 380]
const LEVEL_NAMES := ["屋台並み", "町の焼肉屋", "人気店", "名店", "行列のできる名店"]
# 成長要素：名前 → 必要レベル・値段・説明
const UPGRADES := {
	"extend": {"lv": 2, "price": 30000, "name": "営業時間の延長", "desc": "閉店を23時→24時に（お客さんが増える）"},
	"touch": {"lv": 2, "price": 50000, "name": "タッチパネル注文", "desc": "テーブル席の注文をお客さんが自分で入れる"},
	"dishwasher": {"lv": 3, "price": 80000, "name": "食洗機", "desc": "洗い物を入れてボタンひとつで洗える（置き場所は自由）"},
	"selfcut": {"lv": 3, "price": 40000, "name": "自家カット", "desc": "安い塊肉を仕入れて、作業台のまな板で自分で切る"},
	"premium": {"lv": 4, "price": 60000, "name": "上タン塩・特上カルビ", "desc": "高級部位をメニューに追加（食通が喜ぶ）"},
}
# アルバイトの担当：日給と説明
const ROLES := {
	"cook": {"name": "焼き担当", "wage": 9000, "desc": "カウンターのお客さんの肉を焼いて出す"},
	"hall": {"name": "ホール担当", "wage": 8000, "desc": "テーブル席の注文取り・肉と飲み物運び・お会計・網と炭"},
	"clean": {"name": "片づけ担当", "wage": 7000, "desc": "皿下げ・テーブル拭き・皿洗い"},
}
const BLOCK_SLICES := 20

const BOX_PIECES := 20
const SHELF_DAYS := 3


func _ready() -> void:
	for c in MeatData.BASE:
		stock[c] = [{"n": 16, "exp": SHELF_DAYS}]


func has(k: String) -> bool:
	return unlocked.get(k, false)


func level() -> int:
	var lv := 1
	for i in LEVELS.size():
		if fame >= LEVELS[i]:
			lv = i + 1
	return lv


func level_text() -> String:
	var lv := level()
	var t := "店の格 Lv%d %s" % [lv, LEVEL_NAMES[lv - 1]]
	if lv < LEVELS.size():
		t += "（次まで %d）" % int(ceil(LEVELS[lv] - fame))
	return t


## 星をもらうと店の格のポイントがたまる（星3以上で、星が多いほど多く）
func add_fame(stars: float) -> void:
	var lv := level()
	fame += maxf(stars - 2.0, 0.0)
	if level() > lv:
		var names: Array[String] = []
		for k in UPGRADES:
			if UPGRADES[k].lv == level():
				names.append(UPGRADES[k].name)
		say("店の格が上がった！ Lv%d %s%s" % [level(), LEVEL_NAMES[level() - 1], ("\n新しく買える: " + "・".join(names) + "（Bのカタログ）") if not names.is_empty() else ""])


## お客さんのタイプを決める（テーブル席なら団体もある）
func pick_type(table: bool) -> String:
	var r := randf()
	if table and r < 0.18:
		return "group"
	r = randf()
	if r < 0.12:
		return "complainer"
	if r < 0.24 and level() >= 2:
		return "gourmet"
	if r < 0.44 and (day >= 3 or fame >= 30):
		return "regular"
	return "normal"


const TYPE_NAMES := {"normal": "", "regular": "常連", "complainer": "クレーマー", "gourmet": "食通", "group": "団体"}


## タイプで星を調整する（料理の点 avg 0〜1）
static func type_stars(t: String, stars: float, avg: float) -> float:
	match t:
		"complainer":
			if avg < 0.85:
				stars -= 1.0
		"gourmet":
			if avg >= 0.85:
				stars += 1.0
			elif avg < 0.7:
				stars -= 1.0
		"regular":
			stars += 0.5
	return clampf(roundf(stars), 1.0, 5.0)


## タイプで払う額の倍率（常連はチップ、食通は満足すると多めに）
static func type_pay(t: String, avg: float) -> float:
	match t:
		"regular":
			return 1.1
		"gourmet":
			return 1.25 if avg >= 0.85 else 1.0
	return 1.0


static func type_patience(t: String) -> float:
	match t:
		"regular":
			return 1.4
		"complainer":
			return 0.7
	return 1.0


func block_cost(c: String) -> int:
	return int(MeatData.CUTS[c].price * 0.2 / 4.0 * BLOCK_SLICES / 10.0) * 10


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
	add_fame(stars)
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
