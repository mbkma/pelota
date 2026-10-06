## AI input handler that computes strokes and movement decisions automatically
class_name AiController
extends Controller

## Phase-based decision system enum
enum Phase {
	SERVING,
	ANTICIPATION,  ## Before opponent contact - tentative positioning
	LOCK_IN,  ## Opponent contacts ball - compute exact stroke
	WAITING_FOR_HIT,  ## Stroke queued - player swings and hits when the ball arrives
}

const STROKE_TYPE_LABELS := {
	Stroke.StrokeType.FOREHAND: "FH",
	Stroke.StrokeType.BACKHAND: "BH",
	Stroke.StrokeType.SERVE: "SERVE",
	Stroke.StrokeType.FOREHAND_VOLLEY: "FH_VOLLEY",
	Stroke.StrokeType.BACKHAND_VOLLEY: "BH_VOLLEY",
	Stroke.StrokeType.FOREHAND_DROP_VOLLEY: "FH_DROP_VOLLEY",
	Stroke.StrokeType.BACKHAND_DROP_VOLLEY: "BH_DROP_VOLLEY",
	Stroke.StrokeType.FOREHAND_DROP_SHOT: "FH_DROP",
	Stroke.StrokeType.BACKHAND_DROP_SHOT: "BH_DROP",
	Stroke.StrokeType.BACKHAND_SLICE: "BH_SLICE",
}

## Chance range to follow an attacking shot to the net, by net play skill (rare occasions).
const NET_APPROACH_CHANCE_MIN: float = 0.05
const NET_APPROACH_CHANCE_MAX: float = 0.35
## Distance from the net (m) the AI takes up when playing at the net.
const NET_POSITION_DEPTH: float = 3.5
## The AI only follows an attack to the net when it hits from at least this far inside the
## baseline (m), i.e. after attacking a short ball.
const NET_APPROACH_INSIDE_BASELINE: float = 1.0
## Baseline depth (m from the net) the AI recovers to.
const BASELINE_POSITION_DEPTH: float = 14.0
## Contact height range (m) of a ball the AI takes where it is; outside it waits for the
## apex after the bounce. At the net it volleys higher balls.
const CONTACT_HEIGHT_RANGE := Vector2(0.5, 1.5)
const VOLLEY_HEIGHT_RANGE := Vector2(0.3, 2.3)

## High-level strategy resource used to orchestrate shot planning.
@export var point_strategy: PointStrategy

## Pending stroke to execute (queued by controller, executed by player)
var _pending_stroke: Stroke = null

## Current phase in rally cycle
var _current_phase: Phase = Phase.ANTICIPATION

## Whether the AI moved in to play at the net; it stays there until the point ends.
var _plays_at_net: bool = false


func _reset_to_anticipation() -> void:
	_current_phase = Phase.ANTICIPATION
	_pending_stroke = null


func _log_strategy(message: String) -> void:
	DebugLogger.log(self, message)


func _ready() -> void:
	super()  # Call base class initialization
	if not validate_player():
		set_process(false)
		set_physics_process(false)
		return

	# Set logger name to identify this AI controller's player
	set_meta("logger_name", "%s (AI)" % player.player_data.last_name)

	if not point_strategy:
		push_error("AiController: point_strategy must be configured")
		set_process(false)
		return

	point_strategy = point_strategy.duplicate(true)
	if not point_strategy:
		push_error("AiController: Failed to instantiate point strategy")
		set_process(false)
		return
	if not point_strategy.validate_configuration():
		push_error("AiController: point_strategy configuration is invalid")
		set_process(false)
		set_physics_process(false)
		return

	point_strategy.setup(player)

	# Connect to ball_hit signal to handle defensive positioning and phase reset
	player.ball_hit.connect(_on_hit_frame)

	_log_strategy("AI Controller initialized")


## Initiate a serve using current tactic
func _make_serve() -> void:
	var stroke: Stroke = point_strategy.compute_serve()
	if not stroke:
		push_error("AiController._make_serve: Tactic returned null stroke")
		return

	_log_strategy(
		(
			(
				"Serve decision: type=%s intended_power=%.1f spin=(%.2f, %.2f, %.2f) "
				+ "intended_target=(%.2f, %.2f, %.2f)"
			)
			% [
				_stroke_type_to_string(stroke.stroke_type),
				stroke.intended_stroke_power,
				stroke.stroke_spin.x,
				stroke.stroke_spin.y,
				stroke.stroke_spin.z,
				stroke.intended_stroke_target.x,
				stroke.intended_stroke_target.y,
				stroke.intended_stroke_target.z
			]
		)
	)
	_log_strategy(
		(
			"Serve execution: actual_power=%.1f actual_target=(%.2f, %.2f, %.2f)"
			% [
				stroke.stroke_power,
				stroke.stroke_target.x,
				stroke.stroke_target.y,
				stroke.stroke_target.z
			]
		)
	)
	player.prepare_serve()
	await get_tree().create_timer(GameConstants.INPUT_STARTUP_DELAY + 1.5).timeout
	_pending_stroke = stroke


## Request the AI to serve
func request_serve() -> void:
	_current_phase = Phase.SERVING
	_make_serve()


## Update controller state - called by Player each frame
## Routes to appropriate phase handler based on current game state
func update(delta: float = 0.0) -> void:
	if not validate_player():
		return

	if not player.ball:
		return

	# Route to appropriate phase handler
	match _current_phase:
		Phase.SERVING:
			return
		Phase.ANTICIPATION:
			_anticipation_phase(delta)
		Phase.LOCK_IN:
			_lock_in_phase()
		Phase.WAITING_FOR_HIT:
			pass  # Player times the swing and hits; we just wait


## Get movement direction from AI decision
func get_move_direction() -> Vector3:
	if not validate_player():
		return Vector3.ZERO

	return player.compute_move_dir()


## Get pending stroke to execute
func get_stroke() -> Stroke:
	return _pending_stroke


## Get aim marker position for UI - overrides base class
func get_aim_marker_position() -> Variant:
	if not _pending_stroke:
		return null
	return _pending_stroke.stroke_target


## Get aim marker visibility state - overrides base class
func should_show_aim_marker() -> bool:
	return _pending_stroke != null


## Compute and prepare a stroke for the given trajectory step
func _queue_stroke(step: TrajectoryStep) -> void:
	var stroke: Stroke = point_strategy.compute_next_stroke(step)
	if not stroke:
		push_error("AiController._queue_stroke: Tactic returned null stroke")
		return
	# Queue stroke and position adjustment to be executed by player
	_pending_stroke = stroke
	match stroke.stroke_intent:
		AiPointContext.ShotIntent.ATTACK:
			player.label_3d.modulate = Color.RED
		AiPointContext.ShotIntent.SAFE:
			player.label_3d.modulate = Color.GREEN
		_:
			player.label_3d.modulate = Color.YELLOW
	_log_strategy(
		(
			(
				"Stroke decision: type=%s intended_power=%.1f actual_power=%.1f "
				+ "spin=(%.2f, %.2f, %.2f) contact_time=%.3f "
				+ "intended_target=(%.2f, %.2f, %.2f) actual_target=(%.2f, %.2f, %.2f)"
			)
			% [
				_stroke_type_to_string(stroke.stroke_type),
				stroke.intended_stroke_power,
				stroke.stroke_power,
				stroke.stroke_spin.x,
				stroke.stroke_spin.y,
				stroke.stroke_spin.z,
				step.time,
				stroke.intended_stroke_target.x,
				stroke.intended_stroke_target.y,
				stroke.intended_stroke_target.z,
				stroke.stroke_target.x,
				stroke.stroke_target.y,
				stroke.stroke_target.z
			]
		)
	)
	adjust_player_position_to_stroke(player, step, stroke)


## PHASE 1: Anticipation phase - detect incoming ball and transition to lock-in
## Before opponent contacts ball, tentatively position defensively
func _anticipation_phase(_delta: float) -> void:
	# Check if ball is flying towards us
	if is_flying_towards(player, player.ball):
		# Ball is coming - transition to lock-in phase
		var ball_pos = player.ball.global_position
		_log_strategy(
			(
				"Ball incoming at (%.2f, %.2f, %.2f) - transitioning to LOCK_IN"
				% [ball_pos.x, ball_pos.y, ball_pos.z]
			)
		)
		_current_phase = Phase.LOCK_IN


## PHASE 2: Lock-in phase - compute exact stroke when opponent hits ball
## Triggered when ball is detected flying towards us
func _lock_in_phase() -> void:
	# Already have a pending stroke queued - wait for the hit
	if _pending_stroke:
		_current_phase = Phase.WAITING_FOR_HIT
		return

	# Get closest trajectory step (ball arrival point); at the net, where the ball passes the
	# net position before the bounce
	var closest_step: TrajectoryStep = (
		_get_net_contact_step() if _plays_at_net else get_closest_trajectory_step(player)
	)
	if not closest_step:
		push_error("AiController._lock_in_phase: Could not find trajectory step")
		_log_strategy("LOCK_IN failed: no trajectory step found")
		_current_phase = Phase.ANTICIPATION
		return

	# Take the ball where it is if it is at a playable height, else at the apex after the bounce
	var height_range: Vector2 = CONTACT_HEIGHT_RANGE
	if closest_step.is_volley_contact():
		height_range = VOLLEY_HEIGHT_RANGE
	if closest_step.point.y < height_range.x or closest_step.point.y > height_range.y:
		closest_step = get_closest_apex_after_first_bounce(player)

	if not closest_step:
		push_error("AiController._lock_in_phase: Could not find apex after first bounce")
		_log_strategy("LOCK_IN failed: no apex after bounce found")
		_current_phase = Phase.ANTICIPATION
		return

	# Verify ball is on our side of court
	var closest_ball_position := closest_step.point
	if sign(closest_ball_position.z) != sign(player.position.z):
		push_warning("AiController._lock_in_phase: Ball not on my side of court")
		_log_strategy("LOCK_IN failed: ball not on my side")
		_current_phase = Phase.ANTICIPATION
		return

	# Compute stroke and queue it
	_log_strategy(
		(
			"LOCK_IN: Ball arrival point (%.2f, %.2f, %.2f) at t=%.3f"
			% [closest_step.point.x, closest_step.point.y, closest_step.point.z, closest_step.time]
		)
	)
	_queue_stroke(closest_step)
	_current_phase = Phase.WAITING_FOR_HIT


## Step before the bounce closest to the AI's net position. If the ball bounces before
## reaching the net zone, or the AI cannot get there in time, it plays the ball where it is.
func _get_net_contact_step() -> TrajectoryStep:
	var net_z: float = signf(player.global_position.z) * NET_POSITION_DEPTH
	var closest_step: TrajectoryStep = null
	for step in player.ball.predict_trajectory():
		if step.bounces > 0:
			break
		if not closest_step or absf(step.point.z - net_z) < absf(closest_step.point.z - net_z):
			closest_step = step
	if closest_step and closest_step.is_volley_contact():
		var distance: float = player.global_position.distance_to(closest_step.point)
		var reach_time: float = distance / player.move_speed
		if reach_time <= closest_step.time:
			return closest_step
	return get_closest_trajectory_step(player)


func _on_hit_frame() -> void:
	# Calculate defensive position and request move
	if not validate_player() or not player.opponent:
		_reset_to_anticipation()
		return

	# Use queued stroke position for angle bisector calculation
	var hit_stroke: Stroke = player.queued_stroke
	var inside_court: bool = (
		absf(player.global_position.z)
		<= GameConstants.COURT_LENGTH_HALF - NET_APPROACH_INSIDE_BASELINE
	)
	if (
		not _plays_at_net
		and inside_court
		and hit_stroke.stroke_intent == AiPointContext.ShotIntent.ATTACK
	):
		var approach_chance: float = lerpf(
			NET_APPROACH_CHANCE_MIN, NET_APPROACH_CHANCE_MAX, player.stats.tactical_net_play01()
		)
		_plays_at_net = randf() < approach_chance
		if _plays_at_net:
			_log_strategy("Following the attack to the net")
	var position_depth: float = NET_POSITION_DEPTH if _plays_at_net else BASELINE_POSITION_DEPTH
	var defensive_position: Vector3 = _calculate_angle_bisector_position(
		hit_stroke.stroke_target, position_depth
	)

	# Tell player to move to defensive position after stroke animation finishes
	player.move_to_defensive_position(defensive_position)

	# Reset state for next rally
	_reset_to_anticipation()


func ball_changed(_ball: Ball) -> void:
	_reset_to_anticipation()


func on_lifecycle_phase_changed(_previous_phase: int, current_phase: int) -> void:
	match current_phase:
		MatchLifecycleBus.Phase.SERVING:
			_current_phase = Phase.SERVING
		MatchLifecycleBus.Phase.RALLY:
			if _current_phase == Phase.SERVING:
				_current_phase = Phase.ANTICIPATION
		MatchLifecycleBus.Phase.POINT_ENDED, MatchLifecycleBus.Phase.IDLE:
			_reset_to_anticipation()
			_plays_at_net = false


func get_current_phase() -> Phase:
	return _current_phase


## Calculate the angle bisector position (best defensive position) at `depth` meters from
## the net. Returns the point that maximizes angle coverage to both corners
func _calculate_angle_bisector_position(opponent_hit_position: Vector3, depth: float) -> Vector3:
	var opponent_xz: Vector3 = Vector3(opponent_hit_position.x, 0, opponent_hit_position.z)

	var court_width: float = GameConstants.COURT_WIDTH_HALF
	var service_line_z: float = GameConstants.SERVICE_LINE

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

	var position_z: float = depth * -opponent_side
	var t: float = (position_z - opponent_xz.z) / bisector_direction.z
	var defensive_position: Vector3 = Vector3(
		opponent_xz.x + t * bisector_direction.x, 0.0, position_z
	)

	return defensive_position


func _stroke_type_to_string(stroke_type: Stroke.StrokeType) -> String:
	return STROKE_TYPE_LABELS.get(stroke_type, "UNKNOWN")
