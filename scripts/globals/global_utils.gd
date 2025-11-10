## Global utility functions for game logic and calculations
extends Node

enum Direction { LEFT, RIGHT, FRONT, BEHIND }

enum CheckType { LEFT_RIGHT, FRONT_BEHIND }

## Threshold angle (in radians) for considering object "flying towards" (30 degrees)
const FLYING_TOWARDS_ANGLE_THRESHOLD: float = PI / 6.0

## Minimum velocity magnitude to consider object moving
const VELOCITY_THRESHOLD: float = 0.6


## Check relative position of target relative to player's orientation
func check_relative_position(
	player: Node3D, target_position: Vector3, check_type: CheckType
) -> Direction:
	var player_forward: Vector3 = player.basis.z.normalized()  # Forward vector (Z axis)
	var player_right: Vector3 = player.basis.x.normalized()  # Right vector (X axis)

	var direction_to_target: Vector3 = (target_position - player.position).normalized()

	if check_type == CheckType.LEFT_RIGHT:
		# Check if the target is to the left or right
		var is_to_right: bool = player_right.dot(direction_to_target) > 0
		return Direction.RIGHT if is_to_right else Direction.LEFT
	if check_type == CheckType.FRONT_BEHIND:
		# Check if the target is in front or behind
		var is_in_front: bool = player_forward.dot(direction_to_target) > 0
		return Direction.FRONT if is_in_front else Direction.BEHIND

	return -1


## Check if target is flying towards source based on velocity and direction
func is_flying_towards(source: Node3D, target: Node3D) -> bool:
	# Ensure both source and target are valid
	if source == null or target == null:
		return false

	# Get the current position of the source and the target
	var source_position: Vector3 = source.global_position
	var target_position: Vector3 = target.global_position

	# Calculate the direction vector from the target to the source
	var direction_to_source: Vector3 = (source_position - target_position).normalized()

	# Get the current velocity of the target (assuming it has get_velocity method)
	var velocity: Vector3 = Vector3.ZERO
	if target.has_method("get_velocity"):
		velocity = target.get_velocity()

	# Check if velocity is significant enough
	if velocity.length() > VELOCITY_THRESHOLD:
		var normalized_velocity: Vector3 = velocity.normalized()

		# Check if the angle between the direction to the source and the velocity is small
		var angle: float = direction_to_source.angle_to(normalized_velocity)

		return angle < FLYING_TOWARDS_ANGLE_THRESHOLD

	return false


## Adjust player position to optimal stroke execution point
func adjust_player_position_to_stroke(player: Player, stroke: Stroke) -> void:
	## Calculate the direction from the position
	var x_offset: float
	if stroke.stroke_type == stroke.StrokeType.FOREHAND:
		x_offset = -1.0
	else:
		x_offset = 1.0

	var new_position: Vector3 = stroke.step.point + x_offset * player.basis.x
	new_position.y = player.position.y
	player.move_to(new_position)


## Get optimal ball position for stroke (TODO: Implement)
func get_optimal_ball_position(_player: Player) -> Vector3:
	return Vector3.ZERO


## Get closest trajectory step to player by Z distance
func get_closest_trajectory_step(player: Player) -> TrajectoryStep:
	# Initialize variables to track the closest point
	var closest_trajectory_step: TrajectoryStep
	var closest_z_distance: float = INF  # Start with a large number
	var trajectory: Array[TrajectoryStep] = player.ball.predict_trajectory()

	# Iterate through the ball trajectory to find the closest point in Z
	for step in trajectory:
		var ball_position: Vector3 = step.point
		# Calculate the Z distance
		var z_distance: float = abs(ball_position.z - player.position.z)
		if z_distance < closest_z_distance:
			closest_z_distance = z_distance
			closest_trajectory_step = step

	# Return the closest trajectory step
	return closest_trajectory_step


## Get horizontal distance from source to target in XZ plane
func get_horizontal_distance(source: Node3D, target: Node3D) -> float:
	if not source or not target:
		return 0.0

	# Calculate the direction to the target in the XZ plane
	var direction_to_target: Vector3 = target.position - source.position
	direction_to_target.y = 0  # Ignore the vertical component

	# Calculate and return the horizontal distance
	return direction_to_target.length()


## Get all file paths in a directory with optional extension filter
func get_filepaths_in_directory(directory_path: String, ending: String = "") -> Array[String]:
	var filepaths: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory_path)

	# Open the directory
	if dir != null:
		# List files and directories, including hidden ones
		dir.list_dir_begin()

		var file_name: String = dir.get_next()
		while file_name != "":
			# Skip the current directory (".") and parent directory ("..")
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue

			# Check if it's a directory or a file, and filter by extension
			if dir.current_is_dir():
				pass
			elif ending != "" and file_name.ends_with(ending):
				filepaths.append(directory_path + "/" + file_name)
			elif ending == "":
				filepaths.append(directory_path + "/" + file_name)

			file_name = dir.get_next()
		dir.list_dir_end()  # End directory listing
	else:
		push_error("Error accessing directory path: " + directory_path)

	return filepaths
