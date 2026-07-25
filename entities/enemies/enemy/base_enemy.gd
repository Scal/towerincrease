class_name BaseEnemy3D
extends CharacterBody3D

@export_group("Base Combat")
@export var shooting_interval: float = 5.0
@export var attack_angle: float = PI / 4
@export var projectile_scene: PackedScene
@export_group("Required Nodes")
@export var detection_area: Area3D
@export var undetection_area: Area3D
@export var projectile_spawner: Node3D

var player: Node3D = null
var last_shooting_time: float = 0.0


func _ready() -> void:
	_setup_detection()


func _process(delta: float) -> void:
	_handle_shooting(delta)


func _setup_detection() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
	else:
		push_warning("DetectionArea missing on: ", name)

	if undetection_area:
		undetection_area.body_exited.connect(_on_detection_body_exited)
	else:
		push_warning("UndetectionArea missing on: ", name)


func _handle_shooting(delta: float) -> void:
	if not player or not projectile_scene or not projectile_spawner:
		return

	last_shooting_time += delta
	if last_shooting_time < shooting_interval:
		return

	var target_pos := player.global_position
	var to_player_dir := (target_pos - global_position).normalized()
	var looking_dir := -global_transform.basis.z

	if looking_dir.angle_to(to_player_dir) < attack_angle:
		_spawn_projectile(looking_dir)
		last_shooting_time = 0.0


func _spawn_projectile(dir: Vector3) -> void:
	var instance = projectile_scene.instantiate()
	instance.global_position = projectile_spawner.global_position

	if "direction" in instance:
		instance.direction = dir

	get_tree().current_scene.add_child(instance)


func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body


func _on_detection_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
