class_name Drone
extends BaseEnemy3D

@export_group("Drone Movement")
@export var speed: float = 3.0
@export var turning_speed: float = 3.0
@export var optimal_distance: float = 5.0
@export var distance_eps: float = 1.0
@export var player_height := Vector3(0, 1.5, 0)
@export var max_tilt_angle := PI / 24
@export var tilt_speed := PI / 48


func _process(delta: float) -> void:
	super._process(delta)
	_move_flying(delta)


func _move_flying(delta: float) -> void:
	if not player:
		if not is_zero_approx(rotation.x):
			rotation.x += tilt_speed * delta
		return

	var target_position := player.global_position + player_height
	var to_player_vec := target_position - global_position
	var to_player_dir := to_player_vec.normalized()
	var to_player_dist := to_player_vec.length()

	var target_transform := transform.looking_at(target_position, Vector3.UP)
	transform = transform.interpolate_with(target_transform, turning_speed * delta)

	var movement := to_player_dir * speed * delta

	if not is_zero_approx(movement.y):
		global_position.y += movement.y

	if is_equal_approx(to_player_dist, optimal_distance):
		return

	movement.y = 0.0
	var dist_diff := absf(to_player_dist - optimal_distance)

	if dist_diff < distance_eps:
		movement *= dist_diff / distance_eps

	var tilt := minf(dist_diff / distance_eps, 1.0) * max_tilt_angle

	if to_player_dist > optimal_distance:
		global_position += movement
		rotation.x = -tilt
	else:
		global_position -= movement
		rotation.x = tilt
