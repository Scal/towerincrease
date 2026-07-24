extends CharacterBody3D

const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 9.0
const JUMP_VELOCITY: float = 4.5
const AIR_CONTROL: float = 0.3
const WALL_RUN_GRAVITY: float = 2.0
const LEDGE_CLIMB_SPEED: float = 4.0
const GRAPPLE_PULL_SPEED: float = 25.0
const GRAPPLE_MAX_DIST: float = 30.0

@export var sensitivity: float = 2.8

var is_wall_running: bool = false
var is_climbing_ledge: bool = false
var is_grappling: bool = false
var grapple_point: Vector3 = Vector3.ZERO

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

	var current_speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
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
