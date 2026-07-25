extends CharacterBody3D

const WALK_SPEED: float = 10.0
const RUN_SPEED: float = 20.0
const JUMP_VELOCITY: float = 4.5
const AIR_CONTROL: float = 0.3
const WALL_RUN_GRAVITY: float = 2.0
const LEDGE_CLIMB_SPEED: float = 4.0
const GRAPPLE_PULL_SPEED: float = 25.0
const GRAPPLE_MAX_DIST: float = 30.0

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
var _last_platform_collider: Node3D = null
var _last_platform_basis: Basis = Basis.IDENTITY
var _headbob_cycle: float = 0.0
var _cam_origin_pos: Vector3 = Vector3.ZERO
var _sprint_progress: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Eye
@onready var interact_ray: RayCast3D = $Head/InteractRay
@onready var ledge_check: RayCast3D = $LedgeCheckRay
@onready var ledge_wall_check: RayCast3D = $LedgeWallCheckRay
@onready var grapple_ray: RayCast3D = $Head/GrappleRay


func _ready() -> void:
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

	floor_stop_on_slope = true
	floor_block_on_wall = true
	floor_snap_length = 0.4
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY

	_cam_origin_pos = camera.position


func _process(delta: float) -> void:
	_update_headbob(delta)


func _physics_process(delta: float) -> void:
	_apply_platform_rotation(delta)

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

	var is_running := Input.is_action_pressed("run")
	var target_sprint := 1.0 if is_running else 0.0
	_sprint_progress = move_toward(_sprint_progress, target_sprint, delta * 5.0)

	var current_speed := RUN_SPEED if is_running else WALK_SPEED
	var input_dir := Input.get_vector("leftward", "rightward", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		var speed_accel := current_speed if is_on_floor() else current_speed * AIR_CONTROL
		velocity.x = move_toward(velocity.x, direction.x * current_speed, speed_accel)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, speed_accel)
	else:
		var friction := current_speed if is_on_floor() else 0.5
		velocity.x = move_toward(velocity.x, 0, friction)
		velocity.z = move_toward(velocity.z, 0, friction)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.001 * sensitivity)
		head.rotation.x -= event.relative.y * 0.001 * sensitivity
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))

	if Input.is_action_just_pressed("primary"):
		_shoot()
		_light_punch()

	if Input.is_action_just_pressed("secondary"):
		_heavy_punch()
		_toggle_grapple()


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

		_headbob_cycle += speed * delta * (current_freq * 0.1)

		var target_y := _cam_origin_pos.y + sin(_headbob_cycle * 2.0) * current_amp_y
		var target_x := _cam_origin_pos.x + cos(_headbob_cycle) * current_amp_x

		camera.position.y = lerpf(camera.position.y, target_y, delta * 15.0)
		camera.position.x = lerpf(camera.position.x, target_x, delta * 15.0)
	else:
		_headbob_cycle = 0.0
		camera.position = camera.position.lerp(_cam_origin_pos, delta * headbob_reset_speed)


func _apply_platform_rotation(delta: float) -> void:
	if not is_on_floor():
		_last_platform_collider = null
		return

	var collider := get_last_slide_collision()
	if not collider:
		_last_platform_collider = null
		return

	var floor_node := collider.get_collider() as Node3D
	if not floor_node:
		_last_platform_collider = null
		return

	if floor_node is StaticBody3D and floor_node.constant_angular_velocity != Vector3.ZERO:
		rotate_y(floor_node.constant_angular_velocity.y * delta)
		_last_platform_collider = floor_node
		_last_platform_basis = floor_node.global_transform.basis
		return

	if floor_node == _last_platform_collider:
		var current_basis := floor_node.global_transform.basis
		var rot_delta := current_basis * _last_platform_basis.inverse()

		var yaw_delta := rot_delta.get_euler().y
		rotate_y(yaw_delta)

	_last_platform_collider = floor_node
	_last_platform_basis = floor_node.global_transform.basis


func _check_wall_run() -> void:
	if is_on_wall_only() and velocity.y < 0 and Input.is_action_pressed("forward"):
		is_wall_running = true
	else:
		is_wall_running = false


func _check_ledge_mantle() -> void:
	if is_on_wall() and ledge_wall_check.is_colliding() and not ledge_check.is_colliding():
		if Input.is_action_pressed("forward") or Input.is_action_pressed("jump"):
			is_climbing_ledge = true


func _process_ledge_climb(delta: float) -> void:
	velocity = Vector3.UP * LEDGE_CLIMB_SPEED
	if not ledge_wall_check.is_colliding():
		velocity = -transform.basis.z * WALK_SPEED + Vector3.UP * 2.0
		is_climbing_ledge = false


func _toggle_grapple() -> void:
	if is_grappling:
		is_grappling = false
		return

	if grapple_ray.is_colliding():
		grapple_point = grapple_ray.get_collision_point()
		is_grappling = true


func _process_grapple(_delta: float) -> void:
	var dir := (grapple_point - global_position).normalized()
	velocity = dir * GRAPPLE_PULL_SPEED

	if global_position.distance_to(grapple_point) < 2.0 or is_on_wall():
		is_grappling = false


func _shoot() -> void:
	pass


func _light_punch() -> void:
	pass


func _heavy_punch() -> void:
	pass
