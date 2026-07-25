extends CharacterBody3D

var player: Node3D = null
var turning_speed := 3.0
var speed := 3.0
var attack_angle := PI/4
var optimal_attack_distance := 10.0
var shooting_interval := 5.0
var last_shooting_time = 0.0
var projectile := load("res://entities/enemies/projectile/projectile.tscn") #todo: change to rocket

@onready var detection_area: Area3D = $DetectionArea
@onready var undetection_area: Area3D = $UndetectionArea
@onready var rocket_spawners: Array = [$RocketSpawner1, $RocketSpawner2]
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
		return

	var target_position := player.global_position
	var to_player_distance := (target_position - global_position).length()

	var target_transform := transform.looking_at(target_position, Vector3.UP)
	transform = transform.interpolate_with(target_transform, turning_speed * delta)
	
	if to_player_distance < optimal_attack_distance:
		return
	
	var looking_direction = -basis.z
	var movement = looking_direction * speed * delta
	
	global_position += movement
	


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
		var rocket_instance1 = projectile.instantiate()
		var rocket_instance2 = projectile.instantiate()
		
		scene.add_child(rocket_instance1)
		scene.add_child(rocket_instance2)
		
		rocket_instance1.global_position = rocket_spawners[0].global_position
		rocket_instance2.global_position = rocket_spawners[1].global_position
		
		rocket_instance1.direction = looking_direction
		rocket_instance2.direction = looking_direction
		return


func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body


func _on_detection_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
