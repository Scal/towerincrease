# res://weapons/gun.gd
extends Node3D

signal grapple_started(target_point: Vector3)
signal grapple_ended

enum HookState { IDLE, FLYING, ATTACHED, RETRACTING }

@export_group("Shooting")
@export var damage: float = 25.0
@export var max_fire_distance: float = 100.0
@export var impact_force: float = 10.0
@export var shoot_sound: AudioStream
@export_group("Procedural Recoil")
@export var recoil_kickback: float = 0.15 # Push back along Z axis
@export var recoil_pitch: float = 0.1 # Pitch tilt up (in radians)
@export var recoil_recover_speed: float = 12.0 # Speed of returning back
@export_group("Grapple Hook")
@export var hook_max_distance: float = 40.0
@export var hook_fly_speed: float = 80.0

var _hook_state: HookState = HookState.IDLE
var _target_point: Vector3 = Vector3.ZERO
var _current_hook_pos: Vector3 = Vector3.ZERO
var _hook_rest_transform: Transform3D
var _rope_immediate_mesh: ImmediateMesh
var _tracer_immediate_mesh: ImmediateMesh
var _tracer_timer: float = 0.0
# Initial transforms for procedural recoil return
var _weapon_default_pos: Vector3 = Vector3.ZERO
var _weapon_default_rot: Vector3 = Vector3.ZERO

@onready var hook_mesh: MeshInstance3D = $hook
@onready var muzzle: Marker3D = $Muzzle
@onready var rope_muzzle: Marker3D = $RopeMuzzle
@onready var ray_cast: RayCast3D = $RayCast3D
@onready var rope_mesh_instance: MeshInstance3D = $RopeMesh
@onready var tracer_mesh_instance: MeshInstance3D = $TracerMesh
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var muzzle_light: OmniLight3D = $Muzzle/MuzzleLight


func _ready() -> void:
	# Save resting transforms for procedural recoil calculations
	_weapon_default_pos = position
	_weapon_default_rot = rotation

	if hook_mesh:
		_hook_rest_transform = hook_mesh.transform

	_rope_immediate_mesh = ImmediateMesh.new()
	rope_mesh_instance.mesh = _rope_immediate_mesh

	var rope_mat := StandardMaterial3D.new()
	rope_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_mat.albedo_color = Color(0.7, 0.7, 0.7)
	rope_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rope_mesh_instance.material_override = rope_mat
	rope_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_tracer_immediate_mesh = ImmediateMesh.new()
	tracer_mesh_instance.mesh = _tracer_immediate_mesh

	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.albedo_color = Color(1.0, 0.2, 0.0)
	tracer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tracer_mesh_instance.material_override = tracer_mat
	tracer_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if muzzle_light:
		muzzle_light.visible = false

	if shoot_sound:
		audio_player.stream = shoot_sound


func _process(delta: float) -> void:
	_update_hook(delta)
	_draw_rope()
	_update_effects(delta)
	_update_recoil(delta)


func shoot() -> void:
	_play_shoot_sound()
	_apply_recoil_impulse()

	var hit_point: Vector3
	if ray_cast.is_colliding():
		hit_point = ray_cast.get_collision_point()
		var collider := ray_cast.get_collider()

		if collider and collider.has_method("take_damage"):
			collider.take_damage(damage)

		if collider is RigidBody3D:
			var impulse_dir := -ray_cast.global_transform.basis.z
			collider.apply_impulse(impulse_dir * impact_force, hit_point - collider.global_position)
	else:
		var ray_end := ray_cast.global_transform.origin + (-ray_cast.global_transform.basis.z * max_fire_distance)
		hit_point = ray_end

	_create_shot_effects(hit_point)


func toggle_grapple() -> void:
	_play_shoot_sound()
	if _hook_state != HookState.IDLE:
		_detach_hook()
		return

	if ray_cast.is_colliding():
		var point := ray_cast.get_collision_point()
		if global_position.distance_to(point) <= hook_max_distance:
			_target_point = point
			_current_hook_pos = rope_muzzle.global_position
			_hook_state = HookState.FLYING
			hook_mesh.top_level = true


func stop_grapple() -> void:
	if _hook_state != HookState.IDLE:
		_detach_hook()


func _apply_recoil_impulse() -> void:
	# Instantly apply recoil displacement
	position.z += recoil_kickback
	rotation.x += recoil_pitch


func _update_recoil(delta: float) -> void:
	# Smoothly interpolate back to default position and rotation
	position = position.lerp(_weapon_default_pos, delta * recoil_recover_speed)
	rotation.x = lerpf(rotation.x, _weapon_default_rot.x, delta * recoil_recover_speed)
	rotation.y = lerpf(rotation.y, _weapon_default_rot.y, delta * recoil_recover_speed)
	rotation.z = lerpf(rotation.z, _weapon_default_rot.z, delta * recoil_recover_speed)


func _update_hook(delta: float) -> void:
	match _hook_state:
		HookState.FLYING:
			_current_hook_pos = _current_hook_pos.move_toward(_target_point, hook_fly_speed * delta)
			hook_mesh.global_position = _current_hook_pos

			if _current_hook_pos.is_equal_approx(_target_point):
				_hook_state = HookState.ATTACHED
				grapple_started.emit(_target_point)
		HookState.ATTACHED:
			hook_mesh.global_position = _target_point
		HookState.RETRACTING:
			var return_pos := rope_muzzle.global_position
			_current_hook_pos = _current_hook_pos.move_toward(return_pos, hook_fly_speed * 1.5 * delta)
			hook_mesh.global_position = _current_hook_pos

			if _current_hook_pos.is_equal_approx(return_pos):
				_reset_hook()


func _detach_hook() -> void:
	if _hook_state == HookState.ATTACHED or _hook_state == HookState.FLYING:
		_hook_state = HookState.RETRACTING
		grapple_ended.emit()


func _reset_hook() -> void:
	_hook_state = HookState.IDLE
	hook_mesh.top_level = false
	hook_mesh.transform = _hook_rest_transform


func _draw_rope() -> void:
	_rope_immediate_mesh.clear_surfaces()

	if _hook_state == HookState.IDLE:
		return

	var local_start := rope_mesh_instance.to_local(rope_muzzle.global_position)
	var local_end := rope_mesh_instance.to_local(hook_mesh.global_position)

	_rope_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_rope_immediate_mesh.surface_add_vertex(local_start)
	_rope_immediate_mesh.surface_add_vertex(local_end)
	_rope_immediate_mesh.surface_end()


func _play_shoot_sound() -> void:
	if not audio_player.stream:
		return

	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play()


func _create_shot_effects(to_point: Vector3) -> void:
	if muzzle_light:
		muzzle_light.visible = true

	_tracer_immediate_mesh.clear_surfaces()
	var local_start := tracer_mesh_instance.to_local(muzzle.global_position)
	var local_end := tracer_mesh_instance.to_local(to_point)

	_tracer_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_tracer_immediate_mesh.surface_add_vertex(local_start)
	_tracer_immediate_mesh.surface_add_vertex(local_end)
	_tracer_immediate_mesh.surface_end()

	_tracer_timer = 0.05


func _update_effects(delta: float) -> void:
	if _tracer_timer > 0.0:
		_tracer_timer -= delta
		if _tracer_timer <= 0.0:
			_tracer_immediate_mesh.clear_surfaces()
			if muzzle_light:
				muzzle_light.visible = false
