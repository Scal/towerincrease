# res://world/around_world.gd
extends Node3D

signal game_over

@export_group("Drill Reaction Mechanics")
@export var drill_speed: float = 2.0
@export var drill_rotation_speed: float = 2.0
@export var recoil_speed_multiplier: float = 2.5
@export var recoil_duration: float = 1.0

var _is_recoiling: bool = false
var _recoil_timer: float = 0.0
var _is_game_over: bool = false


func _physics_process(delta: float) -> void:
	if _is_game_over:
		return

	_handle_world_movement(delta)
	_update_bodies_physics()


func take_damage(_amount: float = 0.0) -> void:
	if _is_game_over:
		return

	_is_recoiling = true
	_recoil_timer = recoil_duration


func _handle_world_movement(delta: float) -> void:
	if _is_recoiling:
		_recoil_timer -= delta
		if _recoil_timer <= 0.0:
			_is_recoiling = false
			_recoil_timer = 0.0

		# Recoil inverts relative movement
		rotate_y(-drill_rotation_speed * recoil_speed_multiplier * delta)
		global_position.y += drill_speed * recoil_speed_multiplier * delta

		if global_position.y >= 0.0:
			global_position.y = 0.0
			_trigger_game_over()
	else:
		# Normal state: world rotates opposite to drill, moves DOWN relative to static drill
		rotate_y(drill_rotation_speed * delta)
		global_position.y -= drill_speed * delta


func _update_bodies_physics() -> void:
	# Linear & angular velocity for StaticBody3D nodes inside the world container
	var current_rot_speed: float = (-drill_rotation_speed * recoil_speed_multiplier) if _is_recoiling else drill_rotation_speed
	var current_move_speed: float = (drill_speed * recoil_speed_multiplier) if _is_recoiling else -drill_speed

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
