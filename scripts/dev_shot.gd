extends Node
## 開発用：起動引数 --shot=<out_dir> で自動操作してスクリーンショットを撮る

var out := "/tmp"
var t := 0.0
var step := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			out = a.substr(7)


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("shot ", name)


func _process(dt: float) -> void:
	t += dt
	var m = Game.main
	var p: Player = m.player
	match step:
		0:
			if t > 1.0:
				# カウンターの七輪の前に立ち、肉を並べる
				var g: Grill = m.grills[1]
				g.coal = 1.1
				g.vent = 0.9
				g.heat = 1.0
				var cuts := ["karubi", "karubi", "tan", "harami", "rosu"]
				var offs := [Vector3(-0.07, 0, -0.05), Vector3(0.06, 0, -0.06), Vector3(-0.05, 0, 0.06), Vector3(0.06, 0, 0.05), Vector3(0, 0, 0)]
				for i in cuts.size():
					var me := Meat.new().setup(cuts[i])
					m.items_root.add_child(me)
					p.held = null
					me.container = null
					p.pick(me)
					g.primary(p, g.to_global(offs[i] + Vector3(0, 0.2, 0)), Vector3.UP)
					me.sear = [[0.0, 0.0], [0.6, 0.2], [0.9, 0.7], [0.3, 0.0], [1.3, 0.8]][i]
					me.core = [0.0, 0.4, 0.8, 0.2, 1.1][i]
					me.flipped = false
				var pl := Plate.new()
				m.items_root.add_child(pl)
				pl.global_position = g.global_position + Vector3(0.45, 0.0, 0.05)
				for i in 3:
					var me2 := Meat.new().setup("karubi")
					m.items_root.add_child(me2)
					pl.add_meat(me2)
				p.global_position = Vector3(-1.6, 0.05, -2.05)
				p.rotation.y = PI
				p.cam.rotation.x = -0.75
				m.open_shop()
				step = 1
				t = 0
		1:
			if t > 4.0:
				_shot("grill_close")
				p.global_position = Vector3(-1.6, 0.05, -1.75)
				p.cam.rotation.x = -1.3
				p.cam.rotation.x = -0.25
				step = 2
				t = 0
		2:
			if t > 1.0:
				_shot("meat_macro")
				p.global_position = Vector3(-1.6, 0.05, -2.05)
				p.cam.rotation.x = -0.25
				step = 5
				t = 0
		5:
			if t > 1.0:
				_shot("counter_view")
				p.global_position = Vector3(4.0, 0.05, -2.0)
				p.rotation.y = PI * 0.75
				p.cam.rotation.x = -0.15
				step = 3
				t = 0
		3:
			if t > 1.0:
				_shot("shop_view")
				p.global_position = Vector3(-1.0, 0.05, -2.6)
				p.rotation.y = 0.0
				p.cam.rotation.x = -0.2
				step = 4
				t = 0
		4:
			if t > 1.0:
				_shot("kitchen_view")
				get_tree().quit()
