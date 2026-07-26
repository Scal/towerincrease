class_name Pop
extends BaseEnemy3D

enum State {
	PATROL,
	CHASE,
	SHOOT,
	RECOVERY,
}

@export_group("Pop Movement")
@export var speed: float = 4.0
@export var turning_speed: float = 6.0
@export var optimal_distance: float = 8.0
@export var distance_eps: float = 1.5
@export_group("Pop Combat")
@export var fire_rate: float = 1.5
@export var shoot_prep_time: float = 0.2
@export var recovery_time: float = 0.3

var current_state: State = State.PATROL
var _prep_timer: float = 0.0
var _shoot_cooldown_timer: float = 0.0
var _recovery_timer: float = 0.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	super._ready()
	_setup_nav_agent()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	_update_timers(delta)
	_apply_gravity(delta)
	_process_state(delta)

	move_and_slide()


func _setup_nav_agent() -> void:
	await get_tree().physics_frame
	if is_instance_valid(nav_agent):
		nav_agent.path_desired_distance = 1.0
		nav_agent.target_desired_distance = 2.0


func _update_timers(delta: float) -> void:
	if _shoot_cooldown_timer > 0.0:
		_shoot_cooldown_timer -= delta


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _process_state(delta: float) -> void:
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.SHOOT:
			_process_shoot(delta)
		State.RECOVERY:
			_process_recovery(delta)


func _process_patrol(delta: float) -> void:
	_stop_horizontal_movement(delta)

	if is_instance_valid(player):
		current_state = State.CHASE


func _process_chase(delta: float) -> void:
	if not is_instance_valid(player):
		current_state = State.PATROL
		return

	var to_player_vec := player.global_position - global_position
	to_player_vec.y = 0.0
	var dist_to_player := to_player_vec.length()

	if dist_to_player <= optimal_distance + distance_eps and _shoot_cooldown_timer <= 0.0:
		_start_shoot_prep()
		return

	nav_agent.target_position = player.global_position

	var next_pos := nav_agent.get_next_path_position()
	if nav_agent.is_target_reached():
		_stop_horizontal_movement(delta)
		return

	var move_dir := (next_pos - global_position)
	move_dir.y = 0.0

	if move_dir.is_zero_approx():
		_stop_horizontal_movement(delta)
		return

	move_dir = move_dir.normalized()

	if dist_to_player < optimal_distance - distance_eps:
		velocity.x = -move_dir.x * (speed * 0.7)
		velocity.z = -move_dir.z * (speed * 0.7)
	else:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed

	_rotate_towards(move_dir, delta)


func _start_shoot_prep() -> void:
	current_state = State.SHOOT
	_prep_timer = shoot_prep_time
	_stop_horizontal_movement(get_process_delta_time())


func _process_shoot(delta: float) -> void:
	_stop_horizontal_movement(delta)

	if is_instance_valid(player):
		var dir_to_player := (player.global_position - global_position)
		dir_to_player.y = 0.0
		_rotate_towards(dir_to_player.normalized(), delta)

	_prep_timer -= delta
	if _prep_timer <= 0.0:
		_fire()
		_start_recovery()


func _fire() -> void:
	_shoot_cooldown_timer = 1.0 / fire_rate

	if not projectile_scene or not is_instance_valid(projectile_spawner):
		return

	if not projectile_spawner.is_inside_tree():
		return

	var spawn_pos := projectile_spawner.global_position
	var target_pos := player.global_position + Vector3(0, 1.0, 0) if is_instance_valid(player) else spawn_pos + -transform.basis.z
	var fire_dir := (target_pos - spawn_pos).normalized()

	var instance = projectile_scene.instantiate()

	if "direction" in instance:
		instance.direction = fire_dir

	get_tree().current_scene.add_child(instance)
	instance.global_position = spawn_pos


func _start_recovery() -> void:
	current_state = State.RECOVERY
	_recovery_timer = recovery_time


func _process_recovery(delta: float) -> void:
	_stop_horizontal_movement(delta)

	_recovery_timer -= delta
	if _recovery_timer <= 0.0:
		current_state = State.CHASE


func _rotate_towards(dir: Vector3, delta: float) -> void:
	if dir.is_zero_approx():
		return
	var target_transform := transform.looking_at(global_position + dir, Vector3.UP)
	transform = transform.interpolate_with(target_transform, turning_speed * delta)


func _stop_horizontal_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, speed * 3.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, speed * 3.0 * delta)
