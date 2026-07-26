extends CharacterBody3D

const WALK_SPEED: float = 10.0
const RUN_SPEED: float = 20.0
const ACCEL_GROUND: float = 60.0
const ACCEL_AIR: float = 15.0
const FRICTION_GROUND: float = 40.0
const FRICTION_AIR: float = 2.0
const JUMP_VELOCITY: float = 7.0
const WALL_RUN_GRAVITY: float = 2.0
const LEDGE_CLIMB_SPEED: float = 5.0
const GRAPPLE_PULL_SPEED: float = 30.0
const GRAPPLE_STOP_DIST: float = 2.5

@export var sensitivity: float = 2.8
@export_group("Headbob")
@export var headbob_enabled: bool = true
@export var headbob_walk_freq: float = 12.0
@export var headbob_sprint_freq: float = 18.0
@export var headbob_walk_amp_y: float = 0.04
@export var headbob_sprint_amp_y: float = 0.08
@export var headbob_walk_amp_x: float = 0.02
@export var headbob_sprint_amp_x: float = 0.04
@export var headbob_reset_speed: float = 8.0

var is_wall_running: bool = false
var is_climbing_ledge: bool = false
var is_grappling: bool = false
var grapple_point: Vector3 = Vector3.ZERO
var _headbob_cycle: float = 0.0
var _cam_origin_pos: Vector3 = Vector3.ZERO
var _sprint_progress: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Eye
@onready var interact_ray: RayCast3D = $Head/InteractRay
@onready var ledge_check: RayCast3D = $LedgeCheckRay
@onready var ledge_wall_check: RayCast3D = $LedgeWallCheckRay
@onready var weapon: Node3D = $Head/Hand/Gun


func _ready() -> void:
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

	floor_stop_on_slope = true
	floor_block_on_wall = true
	floor_snap_length = 0.4
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	platform_floor_layers = 0xFFFFFFFF

	_cam_origin_pos = camera.position

	if weapon and weapon.has_signal("grapple_started"):
		weapon.grapple_started.connect(
			func(point: Vector3):
				grapple_point = point
				is_grappling = true
		)
		weapon.grapple_ended.connect(
			func():
				is_grappling = false
		)


func _process(delta: float) -> void:
	_update_headbob(delta)


func _physics_process(delta: float) -> void:
	if is_climbing_ledge:
		_process_ledge_climb(delta)
		move_and_slide()
		return

	if is_grappling:
		_process_grapple(delta)
		move_and_slide()
		return

	if not is_on_floor():
		if is_wall_running:
			velocity.y = move_toward(velocity.y, -WALL_RUN_GRAVITY, delta * 10.0)
		else:
			velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_wall_running:
			velocity.y = JUMP_VELOCITY
			velocity += get_wall_normal() * JUMP_VELOCITY
			is_wall_running = false

	_check_wall_run()
	_check_ledge_mantle()

	_handle_movement(delta)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.001 * sensitivity)
		head.rotation.x -= event.relative.y * 0.001 * sensitivity
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	if Input.is_action_just_pressed("primary"):
		if weapon and weapon.has_method("shoot"):
			weapon.shoot()

	if Input.is_action_just_pressed("secondary"):
		if weapon and weapon.has_method("toggle_grapple"):
			weapon.toggle_grapple()


func _handle_movement(delta: float) -> void:
	var is_running := Input.is_action_pressed("run")
	var target_sprint := 1.0 if is_running else 0.0
	_sprint_progress = move_toward(_sprint_progress, target_sprint, delta * 5.0)

	var current_speed := RUN_SPEED if is_running else WALK_SPEED
	var input_dir := Input.get_vector("leftward", "rightward", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	var friction := FRICTION_GROUND if is_on_floor() else FRICTION_AIR

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)


func _update_headbob(delta: float) -> void:
	if not headbob_enabled:
		camera.position = camera.position.lerp(_cam_origin_pos, delta * headbob_reset_speed)
		return

	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_vel.length()

	if is_on_floor() and speed > 0.2 and not (is_climbing_ledge or is_grappling):
		var current_freq := lerpf(headbob_walk_freq, headbob_sprint_freq, _sprint_progress)
		var current_amp_y := lerpf(headbob_walk_amp_y, headbob_sprint_amp_y, _sprint_progress)
		var current_amp_x := lerpf(headbob_walk_amp_x, headbob_sprint_amp_x, _sprint_progress)

		_headbob_cycle += speed * delta * (current_freq * 0.05)

		var target_y := _cam_origin_pos.y + sin(_headbob_cycle * 2.0) * current_amp_y
		var target_x := _cam_origin_pos.x + cos(_headbob_cycle) * current_amp_x

		camera.position.y = lerpf(camera.position.y, target_y, delta * 15.0)
		camera.position.x = lerpf(camera.position.x, target_x, delta * 15.0)
	else:
		_headbob_cycle = 0.0
		camera.position = camera.position.lerp(_cam_origin_pos, delta * headbob_reset_speed)


func _check_wall_run() -> void:
	if is_on_wall_only() and velocity.y < 0 and Input.is_action_pressed("forward"):
		is_wall_running = true
	else:
		is_wall_running = false


func _check_ledge_mantle() -> void:
	if is_on_wall() and ledge_wall_check.is_colliding() and not ledge_check.is_colliding():
		if Input.is_action_pressed("forward") or Input.is_action_pressed("jump"):
			is_climbing_ledge = true


func _process_ledge_climb(_delta: float) -> void:
	velocity = Vector3.UP * LEDGE_CLIMB_SPEED
	if not ledge_wall_check.is_colliding():
		velocity = -transform.basis.z * WALK_SPEED + Vector3.UP * 2.0
		is_climbing_ledge = false


func _process_grapple(delta: float) -> void:
	var dir := (grapple_point - global_position).normalized()

	velocity = velocity.lerp(dir * GRAPPLE_PULL_SPEED, delta * 8.0)

	if global_position.distance_to(grapple_point) < GRAPPLE_STOP_DIST or is_on_wall():
		if weapon and weapon.has_method("stop_grapple"):
			weapon.stop_grapple()
		else:
			is_grappling = false

		velocity.y = JUMP_VELOCITY * 0.8
