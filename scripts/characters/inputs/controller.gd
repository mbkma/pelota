## Base class for player input handling (human/AI)
## Defines the interface that all input methods must implement
@abstract
class_name Controller
extends Node

enum Direction { LEFT, RIGHT, FRONT, BEHIND }

enum CheckType { LEFT_RIGHT, FRONT_BEHIND }

## Threshold angle (in radians) for considering object "flying towards" (30 degrees)
const FLYING_TOWARDS_ANGLE_THRESHOLD: float = PI / 6.0

## Minimum velocity magnitude to consider object moving
const VELOCITY_THRESHOLD: float = 0.6

## Reference to parent player this input handler controls
var player: Player

## Signal emitted when aiming position changes
signal aiming_at_position(position: Vector3)

## Signal emitted when pace/power changes
signal pace_changed(pace: float)

## Signal emitted when input method changes timing
signal input_changed(timing: float)


## Initialize input method (called when scene ready)
func _ready() -> void:
	if not player:
		player = get_parent()
		if not player or not player is Player:
			push_error("InputMethod parent must be a Player node, got: ", get_parent().name)


## Process input each frame for state updates
@abstract
func _process(_delta: float) -> void

## Process physics-related input (movement)
@abstract
func _physics_process(_delta: float) -> void

## Request the input method to initiate a serve
## Implementing classes should handle serve initialization here
@abstract
func request_serve() -> void


## Check relative position of target relative to player's orientation
func check_relative_position(
	check_player: Node3D, target_position: Vector3, check_type: CheckType
) -> Direction:
	var player_forward: Vector3 = check_player.basis.z.normalized()  # Forward vector (Z axis)
	var player_right: Vector3 = check_player.basis.x.normalized()  # Right vector (X axis)

	var direction_to_target: Vector3 = (target_position - check_player.position).normalized()

	if check_type == CheckType.LEFT_RIGHT:
		# Check if the target is to the left or right
		var is_to_right: bool = player_right.dot(direction_to_target) > 0
		return Direction.RIGHT if is_to_right else Direction.LEFT
	if check_type == CheckType.FRONT_BEHIND:
		# Check if the target is in front or behind
		var is_in_front: bool = player_forward.dot(direction_to_target) > 0
		return Direction.FRONT if is_in_front else Direction.BEHIND

	push_error("check_relative_position: Unknown check_type")
	return Direction.LEFT


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
func adjust_player_position_to_stroke(target_player: Player, closest_step: TrajectoryStep) -> void:
	## Calculate the direction from the position
	var x_offset: float
	if target_player.queued_stroke.stroke_type == target_player.queued_stroke.StrokeType.FOREHAND:
		x_offset = -target_player.model.forehand_point.position.x
	else:
		x_offset = -target_player.model.backhand_point.position.x

	var new_position: Vector3 = closest_step.point + x_offset * target_player.basis.x
	new_position.y = target_player.position.y
	target_player.move_to(new_position)


## Get optimal ball position for stroke (TODO: Implement)
func get_optimal_ball_position(_player: Player) -> Vector3:
	return Vector3.ZERO


func get_closest_apex_after_first_bounce(target_player: Player) -> TrajectoryStep:
	var closest_step: TrajectoryStep = null
	var closest_z_distance: float = INF

	var trajectory: Array[TrajectoryStep] = target_player.ball.predict_trajectory()

	for i in range(trajectory.size()):
		var step: TrajectoryStep = trajectory[i]

		# Only consider steps after the first bounce
		if step.bounces != 1:
			continue

		var ball_pos: Vector3 = step.point

		# Check if this step is a local Y apex
		var is_apex: bool = false
		if i > 0 and i < trajectory.size() - 1:
			var prev_y := trajectory[i - 1].point.y
			var next_y := trajectory[i + 1].point.y
			if ball_pos.y >= prev_y and ball_pos.y >= next_y:
				is_apex = true
		elif i == 0 and ball_pos.y >= trajectory[i + 1].point.y:
			is_apex = true
		elif i == trajectory.size() - 1 and ball_pos.y >= trajectory[i - 1].point.y:
			is_apex = true

		# Track the apex closest in Z to the player
		if is_apex:
			var z_distance: float = abs(ball_pos.z - target_player.position.z)
			if z_distance < closest_z_distance:
				closest_z_distance = z_distance
				closest_step = step

	return closest_step



## Get closest trajectory step to player by Z distance
func get_closest_trajectory_step(target_player: Player) -> TrajectoryStep:
	# Initialize variables to track the closest point
	var closest_trajectory_step: TrajectoryStep
	var closest_z_distance: float = INF  # Start with a large number
	var trajectory: Array[TrajectoryStep] = target_player.ball.predict_trajectory()

	# Iterate through the ball trajectory to find the closest point in Z
	for step in trajectory:
		var ball_position: Vector3 = step.point
		# Calculate the Z distance
		var z_distance: float = abs(ball_position.z - target_player.position.z)
		if z_distance < closest_z_distance:
			closest_z_distance = z_distance
			closest_trajectory_step = step

	# Return the closest trajectory step
	return closest_trajectory_step

func calculate_velocity(
	initial_position: Vector3, target_position: Vector3, velocity_z0: float, _spin: Vector3
) -> Vector3:
	var velocity: Vector3 = Vector3.ZERO

	# Time to reach target position
	var time_to_target: float = (target_position.z - initial_position.z) / velocity_z0

	velocity.x = (target_position.x - initial_position.x) / time_to_target
	velocity.y = (
		(0.5 * GameConstants.GRAVITY * time_to_target * time_to_target - initial_position.y) / time_to_target
	)
	velocity.z = velocity_z0

	return velocity


## Validate player reference and state
## Returns true if valid, false otherwise
func validate_player() -> bool:
	if not player:
		push_error("InputMethod has no player reference")
		return false
	if not player is Player:
		push_error("InputMethod player is not a Player instance: ", player.name)
		return false
	return true
