# res://world/around_world.gd
extends Node3D

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)
signal game_over

@export_group("Stats")
@export var max_health: float = 100.0
@export_group("Drill Mechanics")
@export var drill_speed: float = 2.0
@export var drill_rotation_speed: float = 2.0
@export var recoil_speed_multiplier: float = 2.5
# How many Y-units of world progress are lost per 1 unit of damage
@export var damage_to_distance_ratio: float = 0.5

var current_health: float
var _recoil_distance_left: float = 0.0
var _is_game_over: bool = false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if _is_game_over:
		return

	_handle_world_movement(delta)
	_update_bodies_physics()


func take_damage(amount: float) -> void:
	if _is_game_over or amount <= 0.0:
		return

	current_health = max(0.0, current_health - amount)
	damaged.emit(amount)
	#print(amount, current_health)
	health_changed.emit(current_health, max_health)

	# Calculate recoil distance based on damage received
	_recoil_distance_left += amount * damage_to_distance_ratio

	if current_health <= 0.0:
		_trigger_game_over()


func _handle_world_movement(delta: float) -> void:
	if _recoil_distance_left > 0.0:
		# Recoil mode: moving UP relative to static drill
		var step: float = drill_speed * recoil_speed_multiplier * delta
		var actual_step: float = min(step, _recoil_distance_left)

		_recoil_distance_left -= actual_step

		# Rotate back proportionally to movement speed ratio
		var rot_step: float = (actual_step / drill_speed) * drill_rotation_speed
		rotate_y(-rot_step)
		global_position.y += actual_step

		if global_position.y >= 0.0:
			global_position.y = 0.0
			_trigger_game_over()
	else:
		# Normal state: world moves DOWN
		rotate_y(drill_rotation_speed * delta)
		global_position.y -= drill_speed * delta


func _update_bodies_physics() -> void:
	var is_recoiling := _recoil_distance_left > 0.0
	var current_rot_speed: float = (-drill_rotation_speed * recoil_speed_multiplier) if is_recoiling else drill_rotation_speed
	var current_move_speed: float = (drill_speed * recoil_speed_multiplier) if is_recoiling else -drill_speed

	var ang_vel := Vector3(0.0, current_rot_speed, 0.0)
	var lin_vel := Vector3(0.0, current_move_speed, 0.0)

	_apply_physics_to_children(self, ang_vel, lin_vel)


func _apply_physics_to_children(node: Node, ang_vel: Vector3, lin_vel: Vector3) -> void:
	if node is StaticBody3D:
		node.constant_angular_velocity = ang_vel
		node.constant_linear_velocity = lin_vel

	for child in node.get_children():
		_apply_physics_to_children(child, ang_vel, lin_vel)


func _trigger_game_over() -> void:
	if _is_game_over:
		return
	_is_game_over = true
	game_over.emit()
