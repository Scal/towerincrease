# res://world/around_world.gd
extends Node3D

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)

@export_group("Stats")
@export var max_health: float = 100.0

var current_health: float


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return

	current_health = max(0.0, current_health - amount)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)


## Helper method to update physics velocities on static bodies inside world
func update_body_velocities(current_rot_speed: float, current_move_speed: float) -> void:
	var ang_vel := Vector3(0.0, current_rot_speed, 0.0)
	var lin_vel := Vector3(0.0, current_move_speed, 0.0)
	_apply_physics_to_children(self, ang_vel, lin_vel)


func _apply_physics_to_children(node: Node, ang_vel: Vector3, lin_vel: Vector3) -> void:
	if node is StaticBody3D:
		node.constant_angular_velocity = ang_vel
		node.constant_linear_velocity = lin_vel

	for child in node.get_children():
		_apply_physics_to_children(child, ang_vel, lin_vel)
