extends Marker3D

@export_range(0.0, 1.0) var spawn_chance: float = 0.3
@export var enemies: Array[PackedScene] = [
	preload("res://entities/enemies/spider/spider.tscn"),
	preload("res://entities/enemies/turret/turret.tscn"),
	preload("res://entities/enemies/fly/fly.tscn"),
	preload("res://entities/enemies/pop/pop.tscn"),
]
@export var enemies_node_path: NodePath = "/root/World/Enemies"


func trigger_spawn() -> void:
	if Engine.is_editor_hint():
		return

	if randf() > spawn_chance:
		queue_free()
		return

	var valid_enemies := enemies.filter(func(e): return e != null)
	if valid_enemies.is_empty():
		queue_free()
		return

	var enemy_scene: PackedScene = valid_enemies.pick_random()
	var enemy_instance := enemy_scene.instantiate() as Node3D
	if not enemy_instance:
		queue_free()
		return

	force_update_transform()
	var spawn_xform := global_transform

	var target_parent := get_node_or_null(enemies_node_path)
	if not target_parent:
		target_parent = get_tree().current_scene

	if target_parent:
		target_parent.add_child.call_deferred(enemy_instance)
		_apply_enemy_transform.call_deferred(enemy_instance, spawn_xform)

	queue_free()


func _apply_enemy_transform(enemy: Node3D, xform: Transform3D) -> void:
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		enemy.global_transform = xform
