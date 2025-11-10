## AI input handler that computes strokes and movement decisions automatically
class_name AiInput
extends InputMethod

## Available tactics for AI decision-making
@export var tactics: Dictionary[String, Script]

## Current tactic instance for stroke computation
var _current_tactic: Object

## Base position for AI movement (on the baseline)
var _pivot_point: Vector3 = Vector3.ZERO


func _ready() -> void:
	super()  # Call base class initialization
	if not validate_player():
		set_process(false)
		set_physics_process(false)
		return

	_current_tactic = tactics["default"]
	if not _current_tactic:
		push_error("AiInput: Failed to instantiate default tactic")
		set_process(false)
		return

	_current_tactic = _current_tactic.new()
	_current_tactic.setup(player)
	_pivot_point = Vector3(0, 0, sign(player.position.z) * GameConstants.COURT_LENGTH_HALF)

	# Connect to ball_hit signal to move to defensive position
	player.ball_hit.connect(_on_ball_hit)


## Request the AI to serve
func request_serve() -> void:
	make_serve()


## Process stroke decisions based on ball trajectory
func _process(_delta: float) -> void:
	if not validate_player():
		return

	if not player.ball:
		return

	var dist: float = GlobalUtils.get_horizontal_distance(player, player.ball)
	if (
		GlobalUtils.is_flying_towards(player, player.ball)
		and dist > GameConstants.AI_BALL_COMMIT_DISTANCE
	):
		if not player.queued_stroke:
			var closest_step: TrajectoryStep = GlobalUtils.get_closest_trajectory_step(player)
			if not closest_step:
				push_error("AiInput: Could not find ball trajectory step")
				return

			var closest_ball_position: Vector3 = closest_step.point
			if sign(closest_ball_position.z) != sign(player.position.z):
				return

			_do_stroke(closest_step)

	# if dist < 0 or player.ball.velocity.length() < 0.1:
	# 	player.cancel_stroke()


## Process movement decisions
func _physics_process(delta: float) -> void:
	if not validate_player():
		return

	var move_dir: Vector3 = player.compute_move_dir()
	player.apply_movement(move_dir, delta)


## Compute and execute a stroke for the given trajectory step
func _do_stroke(closest_step: TrajectoryStep) -> void:
	if not validate_player():
		push_error("AiInput._do_stroke: Invalid player state")
		return

	if not closest_step:
		push_error("AiInput._do_stroke: closest_step is null")
		return

	if not _current_tactic:
		push_error("AiInput._do_stroke: No tactic assigned")
		return

	var stroke: Stroke = _current_tactic.compute_next_stroke(closest_step)
	if not stroke:
		push_error("AiInput._do_stroke: Tactic returned null stroke")
		return

	player.queue_stroke(stroke)
	GlobalUtils.adjust_player_position_to_stroke(player, stroke)


## Initiate a serve using current tactic
func make_serve() -> void:
	if not validate_player():
		push_error("AiInput.make_serve: Invalid player state")
		return

	if not _current_tactic:
		push_error("AiInput.make_serve: No tactic assigned")
		return

	var stroke: Stroke = _current_tactic.compute_serve()
	if not stroke:
		push_error("AiInput.make_serve: Tactic returned null stroke")
		return

	player.prepare_serve()
	await get_tree().create_timer(GameConstants.INPUT_STARTUP_DELAY + 1.5).timeout
	player.serve(stroke)


## Called when AI player hits the ball - move to defensive position
func _on_ball_hit() -> void:
	if not validate_player() or not player.opponent:
		return

	# Use opponent's queued stroke position (where they will hit the ball from)
	var opponent_hit_position: Vector3 = player.opponent.position
	if player.opponent.queued_stroke:
		opponent_hit_position = player.opponent.queued_stroke.position

	# Calculate angle bisector position (best defensive position)
	var defensive_position: Vector3 = _calculate_angle_bisector_position(opponent_hit_position)

	# Move to the calculated position
	player.move_to(defensive_position)


## Calculate the angle bisector position (best defensive position)
## Returns the point that maximizes angle coverage to both corners
func _calculate_angle_bisector_position(opponent_position: Vector3) -> Vector3:
	var opponent_xz: Vector3 = Vector3(opponent_position.x, 0, opponent_position.z)

	var court_width: float = GameConstants.COURT_WIDTH / 2.0
	var court_depth: float = GameConstants.COURT_LENGTH_HALF
	var service_line_z: float = GameConstants.SERVICE_LINE_Z

	# Determine which side of court the opponent is hitting from
	var opponent_side: float = sign(opponent_xz.z)

	# The two extreme shot directions are the outer left and right points of the opposite service line
	var service_line_left: Vector3 = Vector3(-court_width, 0, -opponent_side * service_line_z)
	var service_line_right: Vector3 = Vector3(court_width, 0, -opponent_side * service_line_z)

	# Calculate vectors from opponent hit position to both service line extremes (on XZ plane)
	var to_left: Vector3 = (service_line_left - opponent_xz).normalized()
	var to_right: Vector3 = (service_line_right - opponent_xz).normalized()

	# The bisector direction is the average of the two directions
	var bisector_direction: Vector3 = (to_left + to_right).normalized()

	print("-------------")
	print("angle bis->left (deg):", bisector_direction.angle_to(to_left) * 180.0/PI)
	print("angle bis->right (deg):", bisector_direction.angle_to(to_right) * 180.0/PI)
	print("bisector_direction:", bisector_direction)
	print("-------------")

	# Store bisector visualization data on player for debug drawer to use
	player.bisector_service_line_left = service_line_left
	player.bisector_service_line_right = service_line_right
	player.bisector_direction = bisector_direction

	# Position AI at the midpoint between the two service line targets, on the baseline
	var baseline_z: float = -opponent_side * court_depth * 0.8

	# Midpoint X between left and right service line targets
	var midpoint_x: float = (service_line_left.x + service_line_right.x) / 2.0

	var defensive_position: Vector3 = Vector3(midpoint_x, 0, baseline_z)

	print("defensive_position", defensive_position)

	return defensive_position
