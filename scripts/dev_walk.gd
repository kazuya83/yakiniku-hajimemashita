extends Node
var t := 0.0
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.hud._begin.call_deferred()
var p0: Vector3
func _process(dt):
	t += dt
	var p = Game.main.player
	if t < 0.5:
		p0 = p.global_position
		return
	Input.action_press("move_f")
	if t > 2.0:
		print("pos0 ", p0, " pos ", p.global_position, " on_floor ", p.is_on_floor(), " vel ", p.velocity)
		get_tree().quit()
