class_name BaseEnemy3D
extends CharacterBody3D

signal health_changed(current: float, max: float)
signal died

@export_group("Stats")
@export var max_health: float = 100.0
@export var turn_speed: float = 8.0
@export_group("Base Combat")
@export var shooting_interval: float = 3.0
@export var attack_angle: float = PI / 4
@export var projectile_scene: PackedScene
@export_group("Required Nodes")
@export var detection_area: Area3D
@export var undetection_area: Area3D
@export var projectile_spawner: Node3D
@export var los_raycast: RayCast3D

var health: float
var player: Node3D = null
var last_shooting_time: float = 0.0


func _ready() -> void:
	health = max_health
	_setup_detection()


func _process(delta: float) -> void:
	_handle_shooting(delta)


func _physics_process(delta: float) -> void:
	if is_instance_valid(player):
		_rotate_towards_player(delta)

	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()


func take_damage(amount: float) -> void:
	health -= amount
	health_changed.emit(health, max_health)

	if health <= 0.0:
		_die()


func _die() -> void:
	died.emit()
	_explode_into_debris()
	queue_free()


func _explode_into_debris() -> void:
	var meshes: Array[MeshInstance3D] = []
	_find_all_meshes(self, meshes)

	var current_scene := get_tree().current_scene

	for mesh_inst in meshes:
		if not mesh_inst.mesh:
			continue

		var global_trans := mesh_inst.global_transform

		if global_trans.basis.determinant() == 0 or global_trans.basis.get_scale().is_zero_approx():
			continue

		var shape := mesh_inst.mesh.create_convex_shape()
		if not shape:
			continue

		var rb_transform := Transform3D(global_trans.basis.orthonormalized(), global_trans.origin)
		var mesh_scale := global_trans.basis.get_scale()

		var rb := RigidBody3D.new()
		rb.global_transform = rb_transform
		rb.mass = 2.0

		var col_shape := CollisionShape3D.new()
		col_shape.shape = shape
		col_shape.scale = mesh_scale

		var debris_mesh := mesh_inst.duplicate() as MeshInstance3D
		debris_mesh.transform = Transform3D.IDENTITY
		debris_mesh.scale = mesh_scale
		debris_mesh.skeleton = NodePath("")

		rb.add_child(debris_mesh)
		rb.add_child(col_shape)
		current_scene.add_child(rb)

		var explosion_dir := (global_trans.origin - global_position).normalized()
		if explosion_dir.is_zero_approx():
			explosion_dir = Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)).normalized()
		else:
			explosion_dir.y += 0.5

		var impulse := explosion_dir * randf_range(3.0, 8.0)
		var torque := Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))

		rb.apply_impulse(impulse)
		rb.apply_torque_impulse(torque)

		_setup_debris_cleanup(rb, 10.0)


func _find_all_meshes(node: Node, out_array: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.visible:
		out_array.append(node)

	for child in node.get_children():
		_find_all_meshes(child, out_array)


func _setup_debris_cleanup(debris: RigidBody3D, lifetime: float) -> void:
	var tween := debris.create_tween()

	tween.tween_interval(lifetime - 1.0)
	tween.tween_property(debris, "scale", Vector3.ZERO, 1.0)
	tween.tween_callback(debris.queue_free)


func _rotate_towards_player(delta: float) -> void:
	var target_pos := player.global_position
	target_pos.y = global_position.y

	var dir := (target_pos - global_position).normalized()

	if dir.is_zero_approx():
		return

	var target_basis := Basis.looking_at(dir, Vector3.UP)

	var current_basis := global_transform.basis.orthonormalized()
	global_transform.basis = current_basis.slerp(target_basis, turn_speed * delta)


func _setup_detection() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
	else:
		push_warning("DetectionArea missing on: ", name)

	if undetection_area:
		undetection_area.body_exited.connect(_on_detection_body_exited)
	else:
		push_warning("UndetectionArea missing on: ", name)


func _handle_shooting(delta: float) -> void:
	if not is_instance_valid(player) or not projectile_scene or not projectile_spawner:
		return

	last_shooting_time += delta
	if last_shooting_time < shooting_interval:
		return

	var spawn_pos := projectile_spawner.global_position

	var target_center := player.global_position + Vector3(0, 1.0, 0)
	var to_player_dir := (target_center - spawn_pos).normalized()
	var looking_dir := -global_transform.basis.z

	if looking_dir.angle_to(to_player_dir) > attack_angle:
		return

	if los_raycast:
		los_raycast.global_position = spawn_pos
		los_raycast.target_position = los_raycast.to_local(target_center)
		los_raycast.force_raycast_update()

		if los_raycast.is_colliding() and los_raycast.get_collider() != player:
			return

	_spawn_projectile(to_player_dir)
	last_shooting_time = 0.0


func _spawn_projectile(dir: Vector3) -> void:
	if not projectile_spawner.is_inside_tree():
		push_error("ProjectileSpawner is not in the scene tree on: ", name)
		return

	var instance := projectile_scene.instantiate()
	var spawn_pos := projectile_spawner.global_position

	if "direction" in instance:
		instance.direction = dir

	if instance is Node3D:
		instance.transform.basis = Basis.looking_at(dir, Vector3.UP)

	get_tree().current_scene.add_child(instance)
	instance.global_position = spawn_pos


func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body


func _on_detection_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
