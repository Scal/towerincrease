extends StaticBody3D

var player: Node3D = null
var player_height := Vector3(0, 1.5, 0)
var turning_speed := 3.0
var attack_angle := PI/4
var max_tilt_angle := PI/4
var tilt_speed := PI/12
var shooting_interval := 5.0
var last_shooting_time = 0.0
var projectile := load("res://entities/enemies/projectile/projectile.tscn")

@onready var detection_area: Area3D = $DetectionArea
@onready var undetection_area: Area3D = $UndetectionArea
@onready var projectile_spawner: Node3D = $head/ProjectileSpawner
@onready var head: Node3D = $head
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
			rotation.x -= tilt_speed * delta * sign(rotation.x)
		return

	var target_position := player.global_position
	var to_player_direction := (target_position - global_position).normalized()

	var target_transform := head.transform.looking_at(target_position, Vector3.UP)
	head.transform = head.transform.interpolate_with(target_transform, turning_speed * delta)
	
	


func _shoot(delta: float) -> void:
	if not player:
		return
	
	last_shooting_time += delta
	if last_shooting_time < shooting_interval:
		return
	
	last_shooting_time = 0.0
	
	var target_position := player.global_position
	var to_player_direction := (target_position - global_position).normalized()
	
	var looking_direction = head.basis.z
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
