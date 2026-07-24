extends CharacterBody3D

var player: Node3D = null
var player_height := Vector3(0, 1.5, 0)
var turning_speed := 1.0
var speed := 15.0
var min_speed := 0.0
var max_speed := 25.0
var acceleration_speed := 4.0
var acceleration_angle := 45.0

@onready var detection_area: Area3D = $DetectionArea


func _ready() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	else:
		push_warning("DetectionArea is not assigned in the inspector for: ", name)


func _process(delta: float) -> void:
	if not player:
		return

	var target_position := player.global_position + player_height
	var to_player_direction := target_position - global_position

	if to_player_direction.is_zero_approx():
		return

	var target_transform := transform.looking_at(target_position, Vector3.UP)
	transform = transform.interpolate_with(target_transform, turning_speed * delta)

	var flying_direction := -global_transform.basis.z
	var to_player_angle := rad_to_deg(flying_direction.angle_to(to_player_direction))

	if to_player_angle < acceleration_angle:
		speed = minf(max_speed, speed + acceleration_speed * delta)
	else:
		speed = maxf(min_speed, speed - acceleration_speed * delta)

	global_position += flying_direction * speed * delta


func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body


func _on_detection_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
