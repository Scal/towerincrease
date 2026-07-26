# res://world/world.gd
extends Node3D

@export_group("Scene References")
## Drag AroundWorld node here
@export var around_world: Node3D
## Drag WorldEnvironment node here
@export var world_environment: WorldEnvironment
## Drag Skyplane MeshInstance3D here (or leave empty to auto-find under AroundWorld/Skyplane)
@export var skyplane: MeshInstance3D
@export_group("Movement Settings")
@export var move_speed: float = 2.0
@export var rotation_speed_deg: float = 45.0
@export var sky_rotation_speed_deg: float = 15.0
@export_group("Damage Effects")
## Speed of damage_progress accumulation per second
@export var damage_speed: float = 0.05
## Max cap for damage_progress
@export var max_damage_progress: float = 1.5

var _skyplane_material: ShaderMaterial
var _current_damage_progress: float = 0.0


func _ready() -> void:
	if not around_world:
		push_error("World: around_world is NULL! Assign it in the Inspector!")
	if not world_environment:
		push_error("World: world_environment is NULL! Assign it in the Inspector!")

	_setup_skyplane_material()


func _physics_process(delta: float) -> void:
	_process_world_movement(delta)
	_process_sky_rotation(delta)
	_process_damage_progress(delta)


func _process_world_movement(delta: float) -> void:
	if not around_world:
		return

	# Move world UP relative to static drill
	around_world.global_position.y += move_speed * delta

	# Rotate world around Y axis
	var rot_rad := deg_to_rad(rotation_speed_deg * delta)
	around_world.rotate_y(rot_rad)


func _process_sky_rotation(delta: float) -> void:
	if not world_environment or not world_environment.environment:
		return

	var sky_rot := deg_to_rad(sky_rotation_speed_deg * delta)
	world_environment.environment.sky_rotation.y += sky_rot


func _process_damage_progress(delta: float) -> void:
	if not _skyplane_material:
		return

	if _current_damage_progress < max_damage_progress:
		_current_damage_progress = minf(_current_damage_progress + damage_speed * delta, max_damage_progress)
		_skyplane_material.set_shader_parameter("damage_progress", _current_damage_progress)


func _setup_skyplane_material() -> void:
	# Auto-find if skyplane wasn't assigned manually in the Inspector
	if not skyplane and around_world:
		skyplane = around_world.get_node_or_null("Skyplane") as MeshInstance3D

	if not skyplane:
		push_warning("World: Skyplane node not found under AroundWorld/Skyplane!")
		return

	# Fallback check for material_override or surface 0
	var mat := skyplane.material_override
	if not mat and skyplane.mesh and skyplane.mesh.get_surface_count() > 0:
		mat = skyplane.mesh.surface_get_material(0)

	if mat is ShaderMaterial:
		_skyplane_material = mat
		var initial_val = _skyplane_material.get_shader_parameter("damage_progress")
		if initial_val != null:
			_current_damage_progress = float(initial_val)
	else:
		push_warning("World: Skyplane material is not a ShaderMaterial!")
