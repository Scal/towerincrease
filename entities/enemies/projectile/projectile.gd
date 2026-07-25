extends Node3D

var direction := Vector3(0, 0, 0)
var speed := 5.0
var world_border := 1000.0

@onready var collision_area: Area3D = $CollisionArea

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("enemies")
	if collision_area:
		collision_area.body_entered.connect(_on_detection_body_entered)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.length() > world_border:
		queue_free()


func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		return
	if body.is_in_group("player"):
		# todo: damage
		print("hit!")
	queue_free()
