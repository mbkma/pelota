## AI controller: computes strokes and movement automatically
class_name AiController
extends Controller

enum Phase {
	SERVING,
	## Waiting for the opponent's shot to come toward the player
	ANTICIPATION,
	## Ball incoming: compute the stroke and move to meet the ball
	LOCK_IN,
	## Stroke queued: the player swings and hits when the ball arrives
	WAITING_FOR_HIT,
}

## Seconds the AI waits before tossing the ball for a serve
const SERVE_DELAY: float = 2.0
## Angle (rad) within which a ball moving toward the player counts as incoming
const INCOMING_ANGLE: float = PI / 6.0
## Ball speed (m/s) below which the ball does not count as incoming
const INCOMING_MIN_SPEED: float = 3.0
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

var _strategy: PointStrategy
## Stroke handed to the player (queued by the controller, executed by the player)
var _pending_stroke: Stroke = null
var _current_phase: Phase = Phase.ANTICIPATION
## Whether the AI moved in to play at the net; it stays there until the point ends.
var _plays_at_net: bool = false


func _ready() -> void:
	set_meta("logger_name", "%s (AI)" % player.player_data.last_name)
	_strategy = PointStrategy.new(player)
	player.ball_hit.connect(_on_player_ball_hit)


func request_serve() -> void:
	_current_phase = Phase.SERVING
	var stroke: Stroke = _strategy.compute_stroke(null)
	_log_stroke("Serve", stroke)
	await get_tree().create_timer(SERVE_DELAY).timeout
	_pending_stroke = stroke


func update(_delta: float) -> void:
	if not player.ball:
		return

	match _current_phase:
		Phase.ANTICIPATION:
			if _is_ball_incoming():
				_current_phase = Phase.LOCK_IN
		Phase.LOCK_IN:
			_lock_in()


func get_move_direction() -> Vector3:
	return player.compute_move_dir()


func get_stroke() -> Stroke:
	return _pending_stroke


func get_aim_marker_position() -> Variant:
	return _pending_stroke.stroke_target if _pending_stroke else null


func get_current_phase() -> Phase:
	return _current_phase


func ball_changed(_ball: Ball) -> void:
	_reset_to_anticipation()


func on_lifecycle_phase_changed(current_phase: MatchLifecycleBus.Phase) -> void:
	match current_phase:
		MatchLifecycleBus.Phase.SERVING:
			_current_phase = Phase.SERVING
		MatchLifecycleBus.Phase.RALLY:
			if _current_phase == Phase.SERVING:
				_current_phase = Phase.ANTICIPATION
		MatchLifecycleBus.Phase.POINT_ENDED, MatchLifecycleBus.Phase.IDLE:
			_reset_to_anticipation()
			_plays_at_net = false


func _reset_to_anticipation() -> void:
	_current_phase = Phase.ANTICIPATION
	_pending_stroke = null


## Whether the ball flies toward the player fast enough to prepare a stroke.
func _is_ball_incoming() -> bool:
	var ball_velocity: Vector3 = player.ball.velocity
	if ball_velocity.length() <= INCOMING_MIN_SPEED:
		return false
	var to_player: Vector3 = player.global_position - player.ball.global_position
	return to_player.angle_to(ball_velocity) < INCOMING_ANGLE


## Computes the stroke for the incoming ball and moves to meet it.
func _lock_in() -> void:
	_current_phase = Phase.ANTICIPATION
	# Where the ball arrives; at the net, where it passes the net position before the bounce.
	var step: TrajectoryStep = (
		_get_net_contact_step() if _plays_at_net else get_closest_trajectory_step()
	)
	if not step:
		return

	# Take the ball where it is if it is at a playable height, else at the apex after the bounce.
	var height_range: Vector2 = (
		VOLLEY_HEIGHT_RANGE if step.is_volley_contact() else CONTACT_HEIGHT_RANGE
	)
	if step.point.y < height_range.x or step.point.y > height_range.y:
		step = get_closest_apex_after_first_bounce()
	# No apex, or the ball does not reach this side (e.g. it ends up in the net).
	if not step or signf(step.point.z) != signf(player.position.z):
		return

	_pending_stroke = _strategy.compute_stroke(step)
	player.label_3d.modulate = _intent_color(_pending_stroke.stroke_intent)
	_log_stroke("Stroke at t=%.3f" % step.time, _pending_stroke)
	move_to_contact(step, _pending_stroke)
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
		var reach_time: float = (
			player.global_position.distance_to(closest_step.point) / player.move_speed
		)
		if reach_time <= closest_step.time:
			return closest_step
	return get_closest_trajectory_step()


## After hitting, maybe follows an attack to the net, then covers the angles of the reply.
func _on_player_ball_hit() -> void:
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
			DebugLogger.log(self, "Following the attack to the net")
	var depth: float = NET_POSITION_DEPTH if _plays_at_net else BASELINE_POSITION_DEPTH
	player.move_to_defensive_position(
		_calculate_angle_bisector_position(hit_stroke.stroke_target, depth)
	)
	_reset_to_anticipation()


## Position at `depth` meters from the net on the bisector of the angle the opponent can play
## into from `opponent_hit_position` (toward both ends of the service line).
func _calculate_angle_bisector_position(opponent_hit_position: Vector3, depth: float) -> Vector3:
	var opponent_xz := Vector3(opponent_hit_position.x, 0, opponent_hit_position.z)
	var opponent_side: float = signf(opponent_xz.z)
	var service_line_z: float = -opponent_side * GameConstants.SERVICE_LINE
	var service_line_left := Vector3(-GameConstants.COURT_WIDTH_HALF, 0, service_line_z)
	var service_line_right := Vector3(GameConstants.COURT_WIDTH_HALF, 0, service_line_z)
	var bisector_direction: Vector3 = (
		(
			(service_line_left - opponent_xz).normalized()
			+ (service_line_right - opponent_xz).normalized()
		)
		. normalized()
	)

	# Shown by the debug drawer
	player.opponent_hit_position = opponent_xz
	player.bisector_service_line_left = service_line_left
	player.bisector_service_line_right = service_line_right
	player.bisector_direction = bisector_direction

	var position_z: float = depth * -opponent_side
	var t: float = (position_z - opponent_xz.z) / bisector_direction.z
	return Vector3(opponent_xz.x + t * bisector_direction.x, 0.0, position_z)


func _intent_color(intent: int) -> Color:
	match intent:
		AiPointContext.ShotIntent.ATTACK:
			return Color.RED
		AiPointContext.ShotIntent.SAFE:
			return Color.GREEN
	return Color.YELLOW


func _log_stroke(label: String, stroke: Stroke) -> void:
	(
		DebugLogger
		. log(
			self,
			(
				"%s: %s power=%.1f spin=%s target=%s (intended %s)"
				% [
					label,
					Stroke.StrokeType.keys()[stroke.stroke_type],
					stroke.stroke_power,
					stroke.stroke_spin,
					stroke.stroke_target,
					stroke.intended_stroke_target,
				]
			)
		)
	)
