class_name Rocket
extends Area3D

@export_group("Flight Settings")
@export var speed: float = 8.0
@export var turn_speed: float = 2.0
@export var lifetime: float = 10.0
@export_group("Combat")
@export var damage: int = 20
@export var explosion_scene: PackedScene

var target: Node3D = null
var direction: Vector3 = Vector3.FORWARD
var _current_lifetime: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0]

	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)


func _process(delta: float) -> void:
	_current_lifetime += delta
	if _current_lifetime >= lifetime:
		explode()
		return

	_move_and_home(delta)


func take_damage(_amount: int = 1) -> void:
	explode()


func explode() -> void:
	if explosion_scene:
		var exp_instance = explosion_scene.instantiate()
		exp_instance.global_position = global_position
		get_tree().current_scene.add_child(exp_instance)

	queue_free()


func _move_and_home(delta: float) -> void:
	if is_instance_valid(target):
		var target_pos := target.global_position + Vector3(0, 1.0, 0)
		var target_dir := (target_pos - global_position).normalized()

		direction = direction.lerp(target_dir, turn_speed * delta).normalized()

		var target_transform := transform.looking_at(global_position + direction, Vector3.UP)
		transform = transform.interpolate_with(target_transform, turn_speed * 2.0 * delta)

	global_position += direction * speed * delta


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

	explode()


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player_hitbox"):
		if area.owner and area.owner.has_method("take_damage"):
			area.owner.take_damage(damage)
		explode()

	elif area.is_in_group("player_projectile"):
		explode()
