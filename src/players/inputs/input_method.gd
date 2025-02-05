class_name InputMethod
extends Node

var player: Player
var stroke = null


# Function to check if the target is flying towards the source
func is_flying_towards(source: Node3D, target: Node3D) -> bool:
	# Ensure both source and target are valid
	if source == null or target == null:
		return false

	# Get the current position of the source and the target
	var source_position = source.global_position
	var target_position = target.global_position

	# Calculate the direction vector from the target to the source
	var direction_to_source = (source_position - target_position).normalized()

	# Get the current velocity of the target (assuming it's a KinematicBody3D or similar)
	var velocity = Vector3.ZERO
	if target.has_method("get_velocity"):
		velocity = target.get_velocity()

	# Normalize the velocity vector
	if velocity.length() > 0.6:
		var normalized_velocity = velocity.normalized()

		# Check if the angle between the direction to the source and the velocity is small
		var angle = direction_to_source.angle_to(normalized_velocity)

		# Define a threshold angle (in radians) to consider as "flying towards"
		var threshold_angle = deg_to_rad(30)  # Adjust this value as needed

		return angle < threshold_angle

	return false


func adjust_player_to_position(position: Vector3):
	## Calculate the direction from the position
	#var daove_to(new_position)

	var new_position = position + 1 * player.right
	new_position.y = player.position.y
	player.move_to(new_position)


func get_closest_ball_position() -> Vector3:  # FIXME: Optimize Performance
	# Initialize variables to track the closest point
	var closest_ball_position: Vector3 = Vector3.ZERO
	var closest_z_distance: float = INF  # Start with a large number

	# Iterate through the ball trajectory to find the closest point in Z
	for ball_position in player.ball.trajectory:
		# Calculate the Z distance
		var z_distance = abs(ball_position.z - player.position.z)
		print(ball_position)
		if z_distance < closest_z_distance:
			closest_z_distance = z_distance
			closest_ball_position = ball_position

	# Now closest_ball_position holds the position of the ball closest to the player in Z
	return closest_ball_position
