## AI input handler that computes strokes and movement decisions automatically
class_name AiInput
extends Controller

## Phase-based decision system enum
enum Phase {
	ANTICIPATION,      ## Before opponent contact - tentative positioning
	LOCK_IN,           ## Opponent contacts ball - compute exact stroke
	TRACKING,          ## Monitor trajectory - update if changes
	PREP_EXECUTION,    ## ~0.5-0.8s before arrival - ensure stroke queued
	WAITING_FOR_HIT    ## Animation playing - waiting for hit frame
}

## Available tactics for AI decision-making
@export var tactics: Dictionary[String, Script]

## Current tactic instance for stroke computation
var _current_tactic: DefaultTactics

## Base position for AI movement (on the baseline)
var _pivot_point: Vector3 = Vector3.ZERO

## Pending stroke to execute (queued by controller, executed by player)
var _pending_stroke: Stroke = null

## Current phase in rally cycle
var _current_phase: Phase = Phase.ANTICIPATION

## Last known ball position for trajectory deviation detection
var _last_ball_position: Vector3 = Vector3.ZERO

## Threshold for re-evaluating stroke due to ball trajectory change (meters)
var _trajectory_deviation_threshold: float = 1.0

## Last time we computed a stroke (to avoid excessive recalculation)
var _last_stroke_computation_time: float = 0.0

## Minimum time between stroke recalculations (seconds)
var _stroke_recalc_cooldown: float = 0.1


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

	# Connect to ball_hit signal to handle defensive positioning and phase reset
	player.ball_hit.connect(_on_hit_frame)


## Request the AI to serve
func request_serve() -> void:
	make_serve()


## Update controller state - called by Player each frame
## Routes to appropriate phase handler based on current game state
func update(delta: float = 0.0) -> void:
	if not validate_player():
		return

	if not player.ball:
		return

	# Route to appropriate phase handler
	match _current_phase:
		Phase.ANTICIPATION:
			_anticipation_phase(delta)
		Phase.LOCK_IN:
			_lock_in_phase()
		Phase.TRACKING:
			_tracking_phase(delta)
		Phase.PREP_EXECUTION:
			_prep_execution_phase(delta)
		Phase.WAITING_FOR_HIT:
			pass  # Player handles execution; we just wait


## Get movement direction from AI decision
func get_move_direction() -> Vector3:
	if not validate_player():
		return Vector3.ZERO

	return player.compute_move_dir()


## Get pending stroke to execute
func get_stroke() -> Stroke:
	return _pending_stroke


## Compute and prepare a stroke for the given trajectory step
func _queue_stroke(closest_step: TrajectoryStep) -> void:
	var stroke: Stroke = _current_tactic.compute_next_stroke(closest_step)
	if not stroke:
		push_error("AiInput._do_stroke: Tactic returned null stroke")
		return

	# Queue stroke and position adjustment to be executed by player
	_pending_stroke = stroke
	adjust_player_position_to_stroke(player, closest_step, stroke)


## PHASE 1: Anticipation phase - detect incoming ball and transition to lock-in
## Before opponent contacts ball, tentatively position defensively
func _anticipation_phase(_delta: float) -> void:
	# Check if ball is flying towards us
	if is_flying_towards(player, player.ball):
		# Ball is coming - transition to lock-in phase
		_current_phase = Phase.LOCK_IN


## PHASE 2: Lock-in phase - compute exact stroke when opponent hits ball
## Triggered when ball is detected flying towards us
func _lock_in_phase() -> void:
	# Already have a pending stroke queued - wait for next phase
	if _pending_stroke:
		_current_phase = Phase.TRACKING
		_last_ball_position = player.ball.position
		_last_stroke_computation_time = Time.get_ticks_msec() / 1000.0
		return

	# Get closest trajectory step (ball arrival point)
	var closest_step := get_closest_trajectory_step(player)
	if not closest_step:
		push_error("AiInput._lock_in_phase: Could not find trajectory step")
		_current_phase = Phase.ANTICIPATION
		return

	# Validate trajectory step is reachable and on correct side
	if closest_step.point.y < 0.5 or closest_step.point.y > 1.5:
		closest_step = get_closest_apex_after_first_bounce(player)

	if not closest_step:
		push_error("AiInput._lock_in_phase: Could not find apex after first bounce")
		_current_phase = Phase.ANTICIPATION
		return

	# Verify ball is on our side of court
	var closest_ball_position := closest_step.point
	if sign(closest_ball_position.z) != sign(player.position.z):
		push_warning("AiInput._lock_in_phase: Ball not on my side of court")
		_current_phase = Phase.ANTICIPATION
		return

	# Compute stroke and queue it
	_queue_stroke(closest_step)
	_current_phase = Phase.TRACKING
	_last_ball_position = closest_step.point
	_last_stroke_computation_time = Time.get_ticks_msec() / 1000.0


## PHASE 3: Tracking phase - monitor ball trajectory for significant changes
## Update stroke if trajectory deviates significantly
func _tracking_phase(_delta: float) -> void:
	if not _pending_stroke:
		# Stroke was cleared (shouldn't happen, but reset to lock-in)
		_current_phase = Phase.LOCK_IN
		return

	# Check if we should transition to prep execution
	if _pending_stroke.step:
		var time_until_arrival: float = _pending_stroke.step.time
		if time_until_arrival < 0.8:  # ~0.5-0.8s before arrival
			_current_phase = Phase.PREP_EXECUTION
			return

	# Check if ball trajectory changed significantly
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_stroke_computation_time < _stroke_recalc_cooldown:
		return  # Don't recalculate too frequently

	var current_ball_position: Vector3 = player.ball.position
	var deviation: float = _last_ball_position.distance_to(current_ball_position)

	#if deviation > _trajectory_deviation_threshold:
		## Ball trajectory changed significantly - recompute stroke
		#var closest_step := get_closest_trajectory_step(player)
		#if closest_step and closest_step.point.y >= 0.5 and closest_step.point.y <= 1.5:
			#_queue_stroke(closest_step)
			#_last_ball_position = closest_step.point
			#_last_stroke_computation_time = current_time


## PHASE 4: Prep & Execution phase - ensure stroke ready, player manages animation
## ~0.5-0.8s before ball arrival, verify stroke is queued for player
func _prep_execution_phase(_delta: float) -> void:
	# Verify stroke is still valid and queued
	if not _pending_stroke:
		push_warning("AiInput._prep_execution_phase: Pending stroke cleared unexpectedly")
		_current_phase = Phase.LOCK_IN
		return

	# Player class handles all animation timing and execution
	# We just ensure stroke is available via get_stroke()
	# Transition happens when player actually executes
	if not player.queued_stroke and _pending_stroke:
		# Stroke hasn't been picked up by player yet - wait
		return


## PHASE 5: On hit frame - cleanup and reset for next rally
## Called via signal when player successfully hits ball
func _on_hit_frame() -> void:
	# Calculate defensive position and request move
	if not validate_player() or not player.opponent:
		_current_phase = Phase.ANTICIPATION
		return

	# Use opponent's queued stroke position for angle bisector calculation
	var opponent_hit_position: Vector3 = player.queued_stroke.stroke_target
	var defensive_position: Vector3 = _calculate_angle_bisector_position(opponent_hit_position)

	# Tell player to move to defensive position after stroke animation finishes
	player.move_to_defensive_position(defensive_position)

	# Reset state for next rally
	_pending_stroke = null
	_current_phase = Phase.ANTICIPATION


func ball_changed(ball: Ball) -> void:
	_current_phase = Phase.ANTICIPATION
	_pending_stroke = null

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

	Loggie.msg("defensive_position: ", defensive_position).info()

	return defensive_position
