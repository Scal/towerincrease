class_name Turret
extends BaseEnemy3D

@export_group("Turret Settings")
@export var rotation_speed: float = 5.0
@export var player_target_offset := Vector3(0, 1.2, 0)
@export_group("Turret Node Links")
@export var rotating_base: Node3D
@export var muzzle: Node3D


func _process(delta: float) -> void:
	super._process(delta)

	_aim_at_player(delta)


func _aim_at_player(delta: float) -> void:
	if not player or not rotating_base:
		return

	var target_pos := player.global_position + player_target_offset

	var base_target_pos := Vector3(target_pos.x, rotating_base.global_position.y, target_pos.z)

	if not base_target_pos.is_equal_approx(rotating_base.global_position):
		var target_base_transform := rotating_base.global_transform.looking_at(base_target_pos, Vector3.UP)
		rotating_base.global_transform = rotating_base.global_transform.interpolate_with(
			target_base_transform,
			rotation_speed * delta,
		)

	if muzzle:
		var muzzle_target_transform := muzzle.global_transform.looking_at(target_pos, Vector3.UP)
		muzzle.global_transform = muzzle.global_transform.interpolate_with(
			muzzle_target_transform,
			rotation_speed * delta,
		)
