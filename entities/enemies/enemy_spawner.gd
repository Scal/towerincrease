# res://world/props/enemy_spawner.gd
extends Marker3D

signal enemy_spawned(enemy: Node3D, spawn_position: Vector3)
signal spawn_failed()

@export_range(0.0, 1.0) var spawn_chance: float = 0.3
@export var enemies: Array[PackedScene] = [
	preload("res://entities/enemies/spider/spider.tscn"),
	preload("res://entities/enemies/turret/turret.tscn"),
	preload("res://entities/enemies/fly/fly.tscn"),
	preload("res://entities/enemies/pop/pop.tscn"),
]


func trigger_spawn() -> void:
	if Engine.is_editor_hint():
		return

	if randf() > spawn_chance:
		spawn_failed.emit()
		queue_free()
		return

	var valid_enemies := enemies.filter(func(e): return e != null)
	if valid_enemies.is_empty():
		spawn_failed.emit()
		queue_free()
		return

	var enemy_scene: PackedScene = valid_enemies.pick_random()
	var enemy_instance := enemy_scene.instantiate() as Node3D
	if not enemy_instance:
		spawn_failed.emit()
		queue_free()
		return

	# 1. Запоминаем мировую трансформацию спавнера ДО добавления в дерево
	force_update_transform()
	var spawn_xform := global_transform

	# 2. Определяем родителя (текущий контейнер секции бура)
	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene

	# 3. Сначала добавляем ноду в дерево
	parent_node.add_child(enemy_instance)

	# 4. Выставляем трансформ СТРОГО ПОСЛЕ добавления в SceneTree
	enemy_instance.global_transform = spawn_xform

	# 5. Убеждаемся, что враг виден и обновлен
	enemy_instance.show()

	print_rich(
		"[color=green][SPAWNER][/color] Spawned [b]%s[/b] at %s under [b]%s[/b]" % [
			enemy_instance.name,
			spawn_xform.origin,
			parent_node.name,
		],
	)

	enemy_spawned.emit(enemy_instance, spawn_xform.origin)

	# 6. Удаляем спавнер на следующем кадре, чтобы не сломать инициализацию
	queue_free()
