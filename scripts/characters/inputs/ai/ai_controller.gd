## AI input handler that computes strokes and movement decisions automatically
class_name AiInput
extends Controller

## Available tactics for AI decision-making
@export var tactics: Dictionary[String, Script]

## Current tactic instance for stroke computation
var _current_tactic: DefaultTactics

## Base position for AI movement (on the baseline)
var _pivot_point: Vector3 = Vector3.ZERO

## Pending stroke to execute (queued by controller, executed by player)
var _pending_stroke: Stroke = null


func _ready() -> void:
	super()  # Call base class initialization
	if not validate_player():
		set_process(false)
		set_physics_process(false)
		return

	_current_tactic = tactics["default"].new()
	if not _current_tactic:
		push_error("AiInput: Failed to instantiate default tactic")
		set_process(false)
		return

	_current_tactic.setup(player)
	_pivot_point = Vector3(0, 0, sign(player.position.z) * GameConstants.COURT_LENGTH_HALF)

	# Connect to ball_hit signal to move to defensive position
	player.ball_hit.connect(_on_ball_hit)


## Request the AI to serve
func request_serve() -> void:
	make_serve()


## Update controller state - called by Player each frame
func update() -> void:
	#print(player.player_data.last_name, " #player.queued_stroke: ", player.queued_stroke)
	#print(player.player_data.last_name, " #player.ball: ", player.ball)

	if not validate_player():
		return

	if not player.ball:
		return

	if player.queued_stroke:
		return

	if (
		is_flying_towards(player, player.ball)
	):
		var closest_step := get_closest_trajectory_step(player)
		if closest_step.point.y < 0.5 or closest_step.point.y > 1.5:
			closest_step = get_closest_apex_after_first_bounce(player)

		if not closest_step:
			push_error("AiInput: Could not find ball trajectory step")
			return

		var closest_ball_position := closest_step.point
		if sign(closest_ball_position.z) != sign(player.position.z):
			push_warning("AiInput: Closest Ball position not on my side")
			return


		_do_stroke(closest_step)


## Get movement direction from AI decision
func get_move_direction() -> Vector3:
	if not validate_player():
		return Vector3.ZERO

	return player.compute_move_dir()


## Get pending stroke to execute
func get_stroke() -> Stroke:
	var stroke: Stroke = _pending_stroke
	_pending_stroke = null  # Clear after returning
	return stroke


## Compute and prepare a stroke for the given trajectory step
func _do_stroke(closest_step: TrajectoryStep) -> void:
	var stroke: Stroke = _current_tactic.compute_next_stroke(closest_step)
	if not stroke:
		push_error("AiInput._do_stroke: Tactic returned null stroke")
		return

	# Queue stroke and position adjustment to be executed by player
	_pending_stroke = stroke
	adjust_player_position_to_stroke(player, closest_step, stroke)


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
	_pending_stroke = stroke


## Called when AI player hits the ball - move to defensive position
func _on_ball_hit() -> void:
	if not validate_player() or not player.opponent:
		return

	# Use opponent's queued stroke position (where they will hit the ball from)
	var opponent_hit_position: Vector3 = player.queued_stroke.stroke_target
	#opponent_hit_position = Vector3(0,0,1)
	# Calculate angle bisector position (best defensive position)
	var defensive_position: Vector3 = _calculate_angle_bisector_position(opponent_hit_position)

	# Wait for stroke animation to finish before moving
	await player.model.stroke_animation_finished

	# Move to the calculated position
	player.move_to(defensive_position)


## Calculate the angle bisector position (best defensive position)
## Returns the point that maximizes angle coverage to both corners
func _calculate_angle_bisector_position(opponent_hit_position: Vector3) -> Vector3:
	var opponent_xz: Vector3 = Vector3(opponent_hit_position.x, 0, opponent_hit_position.z)

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

	# Store bisector visualization data on player for debug drawer to use
	player.opponent_hit_position = opponent_xz
	player.bisector_service_line_left = service_line_left
	player.bisector_service_line_right = service_line_right
	player.bisector_direction = bisector_direction

	var baseline_z: float = 14.0 * -opponent_side  # baseline for this player
	var t: float = (baseline_z - opponent_xz.z) / bisector_direction.z
	var defensive_position: Vector3 = Vector3(
		opponent_xz.x + t * bisector_direction.x,
		0.0,  # player height
		baseline_z
	)

	Loggie.msg("[AI] defensive_position: ", defensive_position).debug()

	return defensive_position
