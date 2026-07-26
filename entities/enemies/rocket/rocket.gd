extends Node3D

var player: Node3D = null
var speed := 8.0
var player_height := Vector3(0, 1.5, 0)
var turning_speed := 4.0
var death_time := 10.0
var death_timer := 0.0

@onready var collision_area: Area3D = $CollisionArea

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("enemies")
	if collision_area:
		collision_area.body_entered.connect(_on_detection_collision)
	else:
		push_warning("UndetectionArea is not assigned in the inspector for: ", name)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	death_timer += delta
	if death_timer > death_time:
		queue_free()
	
	var target_position := player.global_position + player_height

	var target_transform := transform.looking_at(target_position, Vector3.UP)
	transform = transform.interpolate_with(target_transform, turning_speed * delta)
	
	var looking_direction = -basis.z
	var movement = looking_direction * speed * delta
	
	global_position += movement

	
func _on_detection_collision(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		return
	if body.is_in_group("player"):
		body.damage(10.0)
	queue_free()

func set_player(body: Node3D) -> void:
	player = body
