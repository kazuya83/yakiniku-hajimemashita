class_name OrderTablet
extends Node3D
## 発注用タブレット。Eで仕入れ画面を開く


func _ready() -> void:
	Build.box(self, Vector3(0.28, 0.012, 0.2), Vector3(0, 0.006, 0), Build.mat(Color(0.05, 0.05, 0.06), 0.3))
	var scr := Build.box(self, Vector3(0.25, 0.002, 0.17), Vector3(0, 0.013, 0), Build.glow_mat(Color(0.3, 0.6, 1.0), 0.6), false)
	scr.name = "Screen"


func get_hint(_p: Player) -> String:
	var t := "発注タブレット\nE: 肉を発注する（翌朝、段ボールで届く）"
	return t


func use(_p: Player) -> void:
	Game.hud.open_purchase()
