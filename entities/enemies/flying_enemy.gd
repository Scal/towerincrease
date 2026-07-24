extends Node3D

var player = null;
var player_height = Vector3(0, 1.5, 0)
var turning_speed = 1
var speed = 15
var min_speed = 0
var max_speed = 25
var acceleratiion_speed = 4
var acceleration_angle = 45

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = self.get_parent().find_child("Player")
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Если игрока не видно - стоим на месте
	if player == null:
		pass
	
	var player_position = player.position + player_height
	var to_player_direction = player_position - self.position
	
	# Плавно разворачиваемся к игроку 
	var new_transform = self.transform.looking_at(player_position, Vector3.UP)
	self.transform = self.transform.interpolate_with(new_transform, turning_speed * delta)
	new_transform = self.transform.looking_at(player_position, Vector3.RIGHT)
	self.transform = self.transform.interpolate_with(new_transform, turning_speed * delta)
	
	var flying_direction = -get_global_transform().basis.z
	var to_player_angle = rad_to_deg(flying_direction.angle_to(to_player_direction))
	# Враг всегда летит в ту сторону, в которую смотрит
	# Если враг смотрит в сторону игрока - он ускоряется
	# Иначе - замедляется 
	if to_player_angle < acceleration_angle:
		speed = min(max_speed, speed + acceleratiion_speed * delta)
	else:
		speed = max(min_speed, speed - acceleratiion_speed * delta)
	self.position = self.position + flying_direction * speed * delta
