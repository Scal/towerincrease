extends CharacterBody3D

var player: Node3D = null
var player_height := Vector3(0, 1.5, 0)
var turning_speed := 3.0
var speed := 3.0
var attack_angle := PI/4
var max_tilt_angle := PI/24
var tilt_speed := PI/48
var optimal_attack_distance := 5.0
var optimal_attack_eps := 1.0
var shooting_interval := 5.0
var last_shooting_time = 0.0
var projectile := load("res://entities/enemies/projectile/projectile.tscn")

@onready var detection_area: Area3D = $DetectionArea
@onready var undetection_area: Area3D = $UndetectionArea
@onready var projectile_spawner: Node3D = $ProjectileSpawner
@onready var scene: Node3D = null


func _ready() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
	else:
		push_warning("DetectionArea is not assigned in the inspector for: ", name)
		
	if undetection_area:
		undetection_area.body_exited.connect(_on_detection_body_exited)
	else:
		push_warning("UndetectionArea is not assigned in the inspector for: ", name)
	
	scene = get_parent()


func _process(delta: float) -> void:
	_move(delta)
	_shoot(delta)
	
func _move(delta: float) -> void:
	if not player:
		if not is_zero_approx(rotation.x):
			rotation.x += tilt_speed*delta
		return

	var target_position := player.global_position + player_height
	var to_player_direction := (target_position - global_position).normalized()
	var to_player_distance := (target_position - global_position).length()

	var target_transform := transform.looking_at(target_position, Vector3.UP)
	transform = transform.interpolate_with(target_transform, turning_speed * delta)
	
	var movement = to_player_direction * speed * delta
	
	if not is_zero_approx(movement.y):
		global_position.y += movement.y
	
	if is_equal_approx(to_player_distance, optimal_attack_distance):
		return
	
	movement.y = 0.0;
	
	if abs(to_player_distance - optimal_attack_distance) < optimal_attack_eps:
		movement *= abs(to_player_distance - optimal_attack_distance)/optimal_attack_eps
	
	var tilt = minf(abs(to_player_distance - optimal_attack_distance)/optimal_attack_eps, 1.0) * max_tilt_angle
	
	if to_player_distance > optimal_attack_distance:
		global_position += movement
		rotation.x = -tilt
	else:
		global_position -= movement
		rotation.x = tilt
	


func _shoot(delta: float) -> void:
	if not player:
		return
	
	last_shooting_time += delta
	if last_shooting_time < shooting_interval:
		return
	
	last_shooting_time = 0.0
	
	var target_position := player.global_position
	var to_player_direction := (target_position - global_position).normalized()
	
	var looking_direction = -basis.z
	var to_player_angle = looking_direction.angle_to(to_player_direction)
	
	if to_player_angle < attack_angle:
		var projectile_instance = projectile.instantiate()
		projectile_instance.global_position = projectile_spawner.global_position
		projectile_instance.direction = looking_direction
		scene.add_child(projectile_instance)
		return


func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body


func _on_detection_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
