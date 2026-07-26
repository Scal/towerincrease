class_name Spider
extends BaseEnemy3D

enum State {
	PATROL,
	CHASE,
	PREPARE_JUMP,
	JUMPING,
	RECOVERY,
}

const NAV_UPDATE_INTERVAL: float = 0.15

@export_group("Spider Movement")
@export var speed: float = 5.0
@export var turning_speed: float = 8.0
@export var attack_distance: float = 5.0
@export var jump_force: float = 7.0
@export var jump_forward_impulse: float = 12.0
@export var attack_damage: int = 15
@export_group("Spider Cooldowns")
@export var jump_prep_time: float = 0.3
@export var jump_cooldown_time: float = 2.0
@export var recovery_time: float = 0.4
@export_group("Visual Aligning & LOD")
@export var visual_model: Node3D
@export var align_speed: float = 8.0
@export var ik_cull_distance: float = 30.0
@export_group("Debug")
@export var debug_enabled: bool = false

var current_state: State = State.PATROL
var jump_target_dir: Vector3 = Vector3.ZERO
var _prep_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _recovery_timer: float = 0.0
var _nav_update_timer: float = 0.0
var _ik_lod_active: bool = true

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var ik_controller: SpiderIKController = $SpiderIKController


func _ready() -> void:
	super._ready()

	_setup_nav_agent()

	_nav_update_timer = randf_range(0.0, NAV_UPDATE_INTERVAL)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	_update_timers(delta)
	_apply_gravity(delta)
	_process_state(delta)

	move_and_slide()

	_align_with_floor(delta)
	_check_ik_lod()
	_process_debug()


func _setup_nav_agent() -> void:
	await get_tree().physics_frame

	if is_instance_valid(nav_agent):
		nav_agent.path_desired_distance = 0.8
		nav_agent.target_desired_distance = 1.2


func _check_ik_lod() -> void:
	if not is_instance_valid(ik_controller) or not is_instance_valid(player):
		return

	var dist_sq := global_position.distance_squared_to(player.global_position)
	var should_enable := dist_sq < ik_cull_distance * ik_cull_distance

	if _ik_lod_active != should_enable:
		_ik_lod_active = should_enable
		ik_controller.set_ik_enabled(should_enable)


func _align_with_floor(delta: float) -> void:
	if not is_instance_valid(visual_model) or not is_instance_valid(ik_controller):
		return

	var ground_normal := ik_controller.get_ground_normal()

	var root_forward := -global_transform.basis.z.normalized()
	var right := root_forward.cross(ground_normal).normalized()

	if right.is_zero_approx():
		right = global_transform.basis.x.normalized()

	var forward := ground_normal.cross(right).normalized()
	var target_basis := Basis(right, ground_normal, -forward).orthonormalized()

	var current_quat := visual_model.global_transform.basis.orthonormalized().get_rotation_quaternion()
	var target_quat := target_basis.get_rotation_quaternion()
	var interpolated_quat := current_quat.slerp(target_quat, align_speed * delta)

	visual_model.global_transform.basis = Basis(interpolated_quat)
	visual_model.position = Vector3.ZERO


func _update_timers(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	if _nav_update_timer > 0.0:
		_nav_update_timer -= delta


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _process_state(delta: float) -> void:
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.PREPARE_JUMP:
			_process_prepare_jump(delta)
		State.JUMPING:
			_process_jumping(delta)
		State.RECOVERY:
			_process_recovery(delta)


func _process_patrol(delta: float) -> void:
	_stop_horizontal_movement(delta)

	if is_instance_valid(player):
		_change_state(State.CHASE)


func _process_chase(delta: float) -> void:
	if not is_instance_valid(player):
		_change_state(State.PATROL)
		return

	var dist_to_player := global_position.distance_to(player.global_position)

	if dist_to_player <= attack_distance and _cooldown_timer <= 0.0 and is_on_floor():
		_start_jump_prep()
		return

	if _nav_update_timer <= 0.0:
		nav_agent.target_position = player.global_position
		_nav_update_timer = NAV_UPDATE_INTERVAL

	if nav_agent.is_target_reached():
		_stop_horizontal_movement(delta)
		return

	var next_pos := nav_agent.get_next_path_position()
	var move_dir := (next_pos - global_position)
	move_dir.y = 0.0

	if move_dir.is_zero_approx():
		_stop_horizontal_movement(delta)
		return

	move_dir = move_dir.normalized()

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	_rotate_towards(move_dir, delta)


func _start_jump_prep() -> void:
	_change_state(State.PREPARE_JUMP)
	_prep_timer = jump_prep_time

	velocity.x = 0.0
	velocity.z = 0.0

	jump_target_dir = (player.global_position - global_position)
	jump_target_dir.y = 0.0

	if not jump_target_dir.is_zero_approx():
		jump_target_dir = jump_target_dir.normalized()
	else:
		jump_target_dir = -transform.basis.z


func _process_prepare_jump(delta: float) -> void:
	_stop_horizontal_movement(delta)
	_rotate_towards(jump_target_dir, delta)

	_prep_timer -= delta

	if _prep_timer <= 0.0:
		_execute_jump()


func _execute_jump() -> void:
	_change_state(State.JUMPING)
	_cooldown_timer = jump_cooldown_time

	velocity.y = jump_force
	velocity.x = jump_target_dir.x * jump_forward_impulse
	velocity.z = jump_target_dir.z * jump_forward_impulse


func _process_jumping(_delta: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()

		if collider == player and collider.has_method("take_damage"):
			collider.take_damage(attack_damage)
			velocity.x = -jump_target_dir.x * (speed * 0.5)
			velocity.z = -jump_target_dir.z * (speed * 0.5)
			_start_recovery()
			return

	if is_on_floor() and velocity.y <= 0.0:
		_start_recovery()


func _start_recovery() -> void:
	_change_state(State.RECOVERY)
	_recovery_timer = recovery_time


func _process_recovery(delta: float) -> void:
	_stop_horizontal_movement(delta)
	_recovery_timer -= delta

	if _recovery_timer <= 0.0:
		_change_state(State.CHASE)


func _rotate_towards(dir: Vector3, delta: float) -> void:
	if dir.is_zero_approx():
		return

	var target_dir := Vector3(dir.x, 0.0, dir.z).normalized()
	var current_dir := -transform.basis.z
	current_dir.y = 0.0
	current_dir = current_dir.normalized()

	var angle := current_dir.signed_angle_to(target_dir, Vector3.UP)
	rotate_y(clampf(angle, -turning_speed * delta, turning_speed * delta))


func _stop_horizontal_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, speed * 2.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, speed * 2.0 * delta)


func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	if debug_enabled:
		print_rich("[color=cyan][Spider Debug][/color] State change: %s -> %s" % [State.keys()[current_state], State.keys()[new_state]])

	current_state = new_state


func _process_debug() -> void:
	if not debug_enabled:
		return

	if Engine.get_physics_frames() % 60 == 0:
		print_rich(
			"[color=cyan][Spider Debug][/color] Pos: %s | On Floor: %s | State: %s" % [
				global_position,
				is_on_floor(),
				State.keys()[current_state],
			],
		)
