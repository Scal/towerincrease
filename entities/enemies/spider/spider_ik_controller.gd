
class_name SpiderIKController
extends Node3D

@export var root_node: CharacterBody3D
@export var leg_ik_targets: Array[Node3D] = []
@export var leg_raycasts: Array[RayCast3D] = []
@export var rest_targets: Array[Node3D] = []
@export var skeleton_ik_nodes: Array[SkeletonIK3D] = []
@export_group("Step Parameters")
@export var step_distance: float = 0.8
@export var step_height: float = 0.3
@export var step_speed: float = 12.0
@export var raycast_up_offset: float = 1.0
@export_group("Ground Sensing")
@export var min_hits_for_full_confidence: int = 3
@export_group("Debug")
@export var debug_enabled: bool = false

var _ik_enabled: bool = true
var _leg_current_pos: Array[Vector3] = []
var _leg_target_pos: Array[Vector3] = []
var _leg_is_stepping: Array[bool] = []
var _leg_step_progress: Array[float] = []
var _leg_groups: Array[int] = []
var _smoothed_ground_normal: Vector3 = Vector3.UP



func _ready() -> void:
	if not _validate_setup():
		set_physics_process(false)
		return

	
	force_update_transform()
	for target in rest_targets:
		if is_instance_valid(target):
			target.force_update_transform()

	_init_legs()
	_start_skeleton_ik()


func _physics_process(delta: float) -> void:
	if not _ik_enabled or not is_instance_valid(root_node):
		return

	var is_grounded := root_node.is_on_floor()

	for i in leg_ik_targets.size():
		_update_leg(i, delta, is_grounded)

	_update_ground_normal(is_grounded)
	_process_debug()


func set_ik_enabled(enabled: bool) -> void:
	_ik_enabled = enabled

	for ray in leg_raycasts:
		if is_instance_valid(ray):
			ray.enabled = enabled

	for ik in skeleton_ik_nodes:
		if is_instance_valid(ik):
			if enabled:
				ik.start()
			else:
				ik.stop()

	if not enabled:
		for i in leg_ik_targets.size():
			if is_instance_valid(leg_ik_targets[i]) and is_instance_valid(rest_targets[i]):
				var rest_pos := rest_targets[i].global_position
				leg_ik_targets[i].global_position = rest_pos
				_leg_current_pos[i] = rest_pos
				_leg_is_stepping[i] = false


func get_ground_normal() -> Vector3:
	return _smoothed_ground_normal


func _start_skeleton_ik() -> void:
	for ik in skeleton_ik_nodes:
		if is_instance_valid(ik):
			ik.start()


func _update_leg(index: int, delta: float, is_grounded: bool) -> void:
	var target_node := leg_ik_targets[index]
	var rest_node := rest_targets[index]
	var ray := leg_raycasts[index]

	if not is_instance_valid(target_node) or not is_instance_valid(rest_node):
		return

	var ideal_pos := rest_node.global_position

	if is_instance_valid(ray):
		ray.global_position = rest_node.global_position + (root_node.global_transform.basis.y * raycast_up_offset)
		if is_grounded and ray.is_colliding():
			ideal_pos = ray.get_collision_point()

	
	if not is_grounded:
		_leg_current_pos[index] = ideal_pos
		_leg_is_stepping[index] = false
		target_node.global_position = ideal_pos
		return

	var dist_to_ideal := _leg_current_pos[index].distance_to(ideal_pos)

	
	if dist_to_ideal > step_distance * 4.0:
		_leg_current_pos[index] = ideal_pos
		_leg_is_stepping[index] = false
		target_node.global_position = ideal_pos
		return

	
	if not _leg_is_stepping[index] and dist_to_ideal > step_distance and _can_leg_step(index):
		_leg_is_stepping[index] = true
		_leg_step_progress[index] = 0.0
		_leg_target_pos[index] = ideal_pos

	if _leg_is_stepping[index]:
		_leg_step_progress[index] += step_speed * delta
		var t := clampf(_leg_step_progress[index], 0.0, 1.0)

		var current_ground := _leg_current_pos[index].lerp(_leg_target_pos[index], t)
		var height_offset := sin(t * PI) * step_height

		target_node.global_position = current_ground + (root_node.global_transform.basis.y * height_offset)

		if t >= 1.0:
			_leg_is_stepping[index] = false
			_leg_current_pos[index] = _leg_target_pos[index]
	else:
		target_node.global_position = _leg_current_pos[index]


func _can_leg_step(index: int) -> bool:
	if _leg_groups.size() != leg_ik_targets.size():
		return true

	var current_group: int = _leg_groups[index]

	for i in leg_ik_targets.size():
		if _leg_groups[i] != current_group and _leg_is_stepping[i]:
			return false

	return true


func _update_ground_normal(is_grounded: bool) -> void:
	if not is_grounded:
		_smoothed_ground_normal = Vector3.UP
		return

	var sum_normals := Vector3.ZERO
	var hit_count := 0

	for ray in leg_raycasts:
		if is_instance_valid(ray) and ray.is_colliding():
			sum_normals += ray.get_collision_normal()
			hit_count += 1

	if hit_count == 0:
		_smoothed_ground_normal = Vector3.UP
		return

	var raw_normal := (sum_normals / float(hit_count)).normalized()

	if raw_normal.is_zero_approx():
		_smoothed_ground_normal = Vector3.UP
		return

	var target_hits: int = min(min_hits_for_full_confidence, leg_raycasts.size())
	var confidence := clampf(float(hit_count) / float(max(target_hits, 1)), 0.0, 1.0)

	_smoothed_ground_normal = Vector3.UP.slerp(raw_normal, confidence)


func _init_legs() -> void:
	var total_legs := leg_ik_targets.size()
	_leg_current_pos.resize(total_legs)
	_leg_target_pos.resize(total_legs)
	_leg_is_stepping.resize(total_legs)
	_leg_step_progress.resize(total_legs)
	_leg_groups.resize(total_legs)

	for i in total_legs:
		if is_instance_valid(leg_raycasts[i]) and is_instance_valid(root_node):
			leg_raycasts[i].add_exception(root_node)

		var start_pos := rest_targets[i].global_position if is_instance_valid(rest_targets[i]) else global_position
		_leg_current_pos[i] = start_pos
		_leg_target_pos[i] = start_pos
		_leg_is_stepping[i] = false
		_leg_step_progress[i] = 0.0

		if is_instance_valid(leg_ik_targets[i]):
			leg_ik_targets[i].global_position = start_pos

		_leg_groups[i] = i % 2


func _validate_setup() -> bool:
	if not is_instance_valid(root_node):
		push_error("SpiderIKController: 'root_node' is not assigned!")
		return false

	var total_legs := leg_ik_targets.size()
	if total_legs == 0:
		push_error("SpiderIKController: 'leg_ik_targets' array is empty!")
		return false

	if leg_raycasts.size() != total_legs or rest_targets.size() != total_legs:
		push_error("SpiderIKController: Mismatch in array sizes!")
		return false

	return true


func _process_debug() -> void:
	if not debug_enabled:
		return

	if Engine.get_physics_frames() % 30 == 0 and not leg_ik_targets.is_empty():
		var rest_0 := rest_targets[0]
		if is_instance_valid(rest_0):
			var dist := _leg_current_pos[0].distance_to(rest_0.global_position)
			print_rich("[color=yellow][IK Debug][/color] Root Pos: ", root_node.global_position, " | Dist0: ", dist, " | Grounded: ", root_node.is_on_floor(), " | Normal: ", _smoothed_ground_normal)
