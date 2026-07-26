@tool
# res://world/props/drill.gd
extends Node3D

const CONTAINER_NAME := "GeneratedContainer"

@export var parts: Array[PackedScene] = [
	preload("res://world/props/drill_parts/spiral.tscn"),
	preload("res://world/props/drill_parts/spiral_hole.tscn"),
	preload("res://world/props/drill_parts/spiral_broken.tscn"),
]
@export var count: int = 5:
	set(value):
		count = max(0, value)
		_queue_rebuild()
@export var step_distance: float = 10.0:
	set(value):
		step_distance = value
		_queue_rebuild()
@export var rotation_step_deg: float = 90.0:
	set(value):
		rotation_step_deg = value
		_queue_rebuild()
@export var random_seed: int = 12345:
	set(value):
		random_seed = value
		_queue_rebuild()
@export var avoid_consecutive_duplicates: bool = true
@export_group("Direction Settings")
## If true, drill generates DOWNWARDS (0, -10, -20). If false, UPWARDS (0, 10, 20).
@export var build_downwards: bool = false
@export_group("Runtime Settings")
@export var is_procedural_in_game: bool = true
@export var randomize_on_launch: bool = false
@export_group("Editor Tools")
@export var regenerate: bool = false:
	set(value):
		if value:
			_queue_rebuild()
			regenerate = false


func _ready() -> void:
	if Engine.is_editor_hint() or is_procedural_in_game:
		_generate_drill()


func _queue_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		_generate_drill()


func _generate_drill() -> void:
	var old_container := get_node_or_null(CONTAINER_NAME)
	if old_container:
		remove_child(old_container)
		old_container.free()

	var valid_parts := parts.filter(func(p): return p != null)
	if valid_parts.is_empty() or count == 0:
		return

	var container := Node3D.new()
	container.name = CONTAINER_NAME
	add_child(container)

	var in_editor := Engine.is_editor_hint()
	if in_editor and not is_procedural_in_game:
		var root := get_tree().edited_scene_root
		if root:
			container.owner = root

	var rng := RandomNumberGenerator.new()
	if not in_editor and randomize_on_launch:
		rng.randomize()
	else:
		rng.seed = random_seed

	var last_idx := -1

	for i in range(count):
		var available_indices: Array[int] = []
		for idx in range(valid_parts.size()):
			if avoid_consecutive_duplicates and valid_parts.size() > 1 and idx == last_idx:
				continue
			available_indices.append(idx)

		var chosen_list_idx := rng.randi_range(0, available_indices.size() - 1)
		var chosen_idx := available_indices[chosen_list_idx]
		last_idx = chosen_idx

		var scene: PackedScene = valid_parts[chosen_idx]
		var instance := scene.instantiate() as Node3D
		if not instance:
			continue

		container.add_child(instance)

		if in_editor and not is_procedural_in_game:
			var root := get_tree().edited_scene_root
			if root:
				instance.owner = root

		# Direction fix
		var y_dir := -1.0 if build_downwards else 1.0
		instance.position = Vector3(0.0, i * step_distance * y_dir, 0.0)
		instance.rotation.y = deg_to_rad(i * rotation_step_deg)

	if not in_editor:
		# Trigger spawners after full tree notification cycle
		await get_tree().process_frame
		if is_instance_valid(container):
			_trigger_spawners_in_node(container)


func _trigger_spawners_in_node(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("trigger_spawn"):
			child.trigger_spawn()
		else:
			_trigger_spawners_in_node(child)
