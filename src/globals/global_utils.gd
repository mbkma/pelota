extends Node

#const MainMenuScene = "res://src/menus/main-menu.tscn"
#const MatchScene = "res://src/match/match.tscn"
const BALL = preload("res://src/ball.tscn")

const DEBUGGING = false

enum Direction { LEFT, RIGHT, FRONT, BEHIND }

enum CheckType { LEFT_RIGHT, FRONT_BEHIND }


func check_relative_position(
	player: Node3D, target_position: Vector3, check_type: CheckType
) -> Direction:
	var player_forward = player.basis.z.normalized()  # Forward vector (Z axis)
	var player_right = player.basis.x.normalized()  # Right vector (X axis)

	var direction_to_target = (target_position - player.position).normalized()

	if check_type == CheckType.LEFT_RIGHT:
		# Check if the target is to the left or right
		var is_to_right = player_right.dot(direction_to_target) > 0
		return Direction.RIGHT if is_to_right else Direction.LEFT
	elif check_type == CheckType.FRONT_BEHIND:
		# Check if the target is in front or behind
		var is_in_front = player_forward.dot(direction_to_target) > 0
		return Direction.FRONT if is_in_front else Direction.BEHIND

	return -1


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


func adjust_player_position_to_stroke(player: Player, stroke: Stroke):
	## Calculate the direction from the position
	var x_offset: float
	if stroke.stroke_type == stroke.StrokeType.FOREHAND:
		x_offset = -1
	else:
		x_offset = 1

	var new_position = stroke.step.point + x_offset * player.basis.x
	new_position.y = player.position.y
	player.move_to(new_position)


func get_optimal_ball_position(player: Player):  # TODO
	pass

func get_closest_trajectory_step(player: Player) -> TrajectoryStep:  # FIXME: Optimize Performance
	# Initialize variables to track the closest point
	var closest_trajectory_step: TrajectoryStep
	var closest_z_distance: float = INF  # Start with a large number
	var trajectory := player.ball.predict_trajectory()
	# Iterate through the ball trajectory to find the closest point in Z
	for step in trajectory:
		var ball_position := step.point
		# Calculate the Z distance
		var z_distance = abs(ball_position.z - player.position.z)
		#print(ball_position)
		if z_distance < closest_z_distance:
			closest_z_distance = z_distance
			closest_trajectory_step = step

	# Now closest_ball_position holds the position of the ball closest to the player in Z
	return closest_trajectory_step


func get_horizontal_distance(source, target):
	if not source or not target:
		return

	# Get the forward direction of the source
	var forward_vector = -source.transform.basis.z.normalized()

	# Calculate the direction to the target in the XZ plane
	var direction_to_target = target.position - source.position
	direction_to_target.y = 0  # Ignore the vertical component

	# Calculate the horizontal distance
	var horizontal_distance = direction_to_target.length()

	# Determine if the target is in front of the source
	var is_in_front = forward_vector.dot(direction_to_target.normalized()) > 0

	return horizontal_distance


func get_filepaths_in_directory(directory_path: String, ending: String = "") -> Array:
	var filepaths := []
	var dir = DirAccess.open(directory_path)

	# Open the directory
	if dir != null:
		# List files and directories, including hidden ones
		dir.list_dir_begin()

		var file_name = dir.get_next()
		while file_name != "":
			# Skip the current directory (".") and parent directory ("..")
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue

			# Check if it's a directory or a file, and filter by extension
			if dir.current_is_dir():
				print("Found directory: " + file_name)
			elif ending != "" and file_name.ends_with(ending):
				filepaths.append(directory_path + "/" + file_name)
			elif ending == "":
				filepaths.append(directory_path + "/" + file_name)

			file_name = dir.get_next()
		dir.list_dir_end()  # End directory listing
	else:
		print("An error occurred when trying to access the path.")

	return filepaths


func spin_to_gravity(spin: float) -> float:
	return 10 + spin
