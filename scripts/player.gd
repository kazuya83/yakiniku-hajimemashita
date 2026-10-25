class_name Player
extends CharacterBody3D
## 一人称の店員。視線の先の物をマウスで操作する

const REACH := 2.4

var cam: Camera3D
var hold: Node3D
var held: Item = null
var look_target: Node = null
var look_hit := {}
var sens := 0.0022
var _tongs: Node3D
var _bob := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.62
	cam.fov = 72
	cam.near = 0.03
	add_child(cam)
	cam.current = true
	hold = Node3D.new()
	hold.position = Vector3(0.14, -0.2, -0.42)
	cam.add_child(hold)
	_build_tongs()


func _build_tongs() -> void:
	_tongs = Node3D.new()
	_tongs.position = Vector3(0.24, -0.22, -0.35)
	_tongs.rotation = Vector3(-0.15, 0.35, 0.0)
	cam.add_child(_tongs)
	var steel := Build.mat(Color(0.8, 0.8, 0.82), 0.3, 1.0)
	for s in [-1.0, 1.0]:
		var arm := Build.box(_tongs, Vector3(0.008, 0.003, 0.26), Vector3(s * 0.006, 0, -0.1), steel, false)
		arm.rotation.y = -s * 0.03
	Build.box(_tongs, Vector3(0.02, 0.02, 0.07), Vector3(0, 0, 0.04), Build.mat(Color(0.1, 0.1, 0.1), 0.6), false)


func _unhandled_input(e: InputEvent) -> void:
	if get_tree().paused:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= e.relative.x * sens
		cam.rotation.x = clampf(cam.rotation.x - e.relative.y * sens, -1.45, 1.45)
	elif e is InputEventMouseButton and e.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not Game.hud.ticket_open():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if Game.main.build.active:
			Game.main.build.click(e.button_index)
			return
		match e.button_index:
			MOUSE_BUTTON_LEFT:
				_primary()
			MOUSE_BUTTON_RIGHT:
				_secondary()
			MOUSE_BUTTON_WHEEL_UP:
				_scroll(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll(-1)
	elif e.is_action_pressed("use") and not Game.main.build.active:
		if look_target and look_target.has_method("use"):
			look_target.use(self)


func _physics_process(dt: float) -> void:
	var inp := Input.get_vector("move_l", "move_r", "move_f", "move_b")
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
	var spd := 4.6 if Input.is_action_pressed("sprint") else 2.8
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= 9.8 * dt
	move_and_slide()
	if inp.length() > 0.1 and is_on_floor():
		_bob += dt * spd * 2.6
		cam.position.y = 1.62 + sin(_bob) * 0.018
	if Game.main.build.active:
		look_target = null
		Game.hud.set_info("")
		return
	_update_look()
	if Input.is_action_pressed("use") and look_target and look_target.has_method("hold_use"):
		look_target.hold_use(self, dt)
	_tongs.visible = held == null or held is Meat


func _update_look() -> void:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	look_hit = space.intersect_ray(q)
	look_target = null
	if not look_hit.is_empty():
		look_target = _find_target(look_hit.collider)
	var hint := ""
	var info := ""
	if look_target:
		hint = look_target.get_hint(self)
		if look_target.has_method("get_info"):
			info = look_target.get_info(self)
	elif held and not look_hit.is_empty() and look_hit.normal.y > 0.6:
		hint = "左クリック: 置く"
	if info == "" and held and held.has_method("get_info"):
		info = held.get_info(self)
	if Game.hud:
		Game.hud.set_hint(hint, look_target != null)
		Game.hud.set_info(info)


func _find_target(n: Node) -> Node:
	while n and n != Game.main:
		if n.has_method("get_hint"):
			return n
		n = n.get_parent()
	return null


func _primary() -> void:
	if look_hit.is_empty():
		return
	var pos: Vector3 = look_hit.position
	var nrm: Vector3 = look_hit.normal
	if look_target and look_target.has_method("primary"):
		if look_target.primary(self, pos, nrm):
			return
	if held and nrm.y > 0.6:
		place_at(pos)


func _secondary() -> void:
	if look_target and look_target.has_method("secondary"):
		look_target.secondary(self)


func _scroll(d: int) -> void:
	if look_target and look_target.has_method("scroll"):
		look_target.scroll(self, d)


## 物を手に持つ
func pick(it: Item) -> void:
	if held:
		return
	it.detach()
	if it.get_parent():
		it.reparent(hold, false)
	else:
		hold.add_child(it)
	it.position = Vector3(0, -0.02, 0) if it is Grate else Vector3.ZERO
	it.rotation = Vector3(PI if (it is Meat and it.flipped) else 0.0, 0.0, 0.0)
	it.set_held()
	it.container = self
	held = it


func remove_item(n: Node) -> void:
	if held == n:
		held = null


## 手に持っている物を、見ている面の上に置く
func place_at(pos: Vector3) -> void:
	var it := held
	it.detach()
	it.reparent(Game.main.items_root, false)
	it.global_position = pos + Vector3(0, it.rest_offset(), 0)
	it.global_rotation = Vector3(PI if (it is Meat and it.flipped) else 0.0, rotation.y, 0.0)
	it.set_placed()
	if it is Meat and pos.y < 0.12:
		it.dropped = true
		Game.say("床に落としてしまった…")
