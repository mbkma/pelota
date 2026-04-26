extends Camera3D

@export var target: Node3D               # Player node to follow
@export var safe_zone_ratio := 1.0       # Fraction of horizontal FOV where player can move freely (0..1)
@export var rotation_speed := 3.0        # Smooth rotation speed
@export var max_yaw_offset_deg := 25.0   # Max yaw offset from center

var _current_y_rotation := 0.0           # Current camera yaw offset in radians


func _process(delta: float) -> void:
	if target == null:
		return

	# Vector from camera to player
	var cam_pos := global_transform.origin
	var player_pos := target.global_transform.origin
	var to_player := player_pos - cam_pos

	# Ignore player behind camera
	var local := to_local(player_pos)
	if local.z >= 0.0:
		return

	# Flatten vectors to XZ plane for horizontal rotation
	var forward := -global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	var to_player_flat := to_player
	to_player_flat.y = 0
	to_player_flat = to_player_flat.normalized()

	# Angle between camera forward and player direction
	var angle_deg := rad_to_deg(forward.angle_to(to_player_flat))

	# Safe zone in degrees
	var half_fov_deg := fov / 2.0
	var safe_zone_deg := half_fov_deg * safe_zone_ratio

	# Compute target yaw
	var target_yaw_deg := 0.0
	if angle_deg > safe_zone_deg:
		# Player is outside safe zone → rotate toward player
		var direction = sign(forward.cross(to_player_flat).y)  # +1 = right, -1 = left
		var overflow := angle_deg - safe_zone_deg
		target_yaw_deg = clamp(overflow * direction, -max_yaw_offset_deg, max_yaw_offset_deg)
	else:
		# Player inside safe zone → recenter
		target_yaw_deg = 0.0

	# Smoothly interpolate current rotation toward target
	_current_y_rotation = lerp(_current_y_rotation, deg_to_rad(target_yaw_deg), rotation_speed * delta)

	# Apply yaw rotation
	rotation.y = _current_y_rotation
