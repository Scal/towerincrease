extends Node3D

@onready var victory_area: Area3D = $VictoryArea

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if victory_area:
		victory_area.body_entered.connect(_on_detection_victory)
	else:
		push_warning("UndetectionArea is not assigned in the inspector for: ", name)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_detection_victory(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.victory()
