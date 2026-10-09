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
## Chance range to follow a good offensive shot to the net, by net play skill.
const NET_APPROACH_CHANCE_MIN: float = 0.25
const NET_APPROACH_CHANCE_MAX: float = 0.75
## A good offensive shot to approach behind: an attack met in position (positioning quality),
## landing deep or wide (share of the half length or width), and fast (m/s) or with the
## opponent stretched (m from the landing point).
const APPROACH_MIN_POSITIONING: float = 0.7
const APPROACH_DEEP: float = 0.7
const APPROACH_WIDE: float = 0.65
const APPROACH_MIN_SPEED: float = 28.0
const APPROACH_STRETCH_DISTANCE: float = 3.0
## Distance from the net (m) the AI takes up when playing at the net.
const NET_POSITION_DEPTH: float = 3.5
## The AI only follows an attack to the net when it hits from at least this far inside the
## baseline (m), i.e. after attacking a short ball.
const NET_APPROACH_INSIDE_BASELINE: float = 1.0
## Recovery depth behind the baseline (m) for the play style's court position: this far behind
## it on the baseline (0), up to COURT_POSITION_IN inside it (-1) and COURT_POSITION_BACK
## farther back (1).
const RECOVERY_BEHIND_BASELINE: float = 0.7
const COURT_POSITION_IN: float = 1.5
const COURT_POSITION_BACK: float = 2.3
## After a weak shot (met out of position, played safe or landing short) the AI recovers this
## much deeper (m) to cover the opponent's attack; after a good attack it steps this much in.
const WEAK_SHOT_STEP_BACK: float = 1.2
const ATTACK_STEP_IN: float = 0.9
const WEAK_SHOT_POSITIONING: float = 0.5
const SHORT_SHOT_DEPTH: float = 8.0
## Farthest the AI retreats (m) behind its recovery depth for a deep, high ball; beyond it the
## ball is taken higher.
const MAX_RETREAT: float = 2.5
## Height (m) at which the AI meets a groundstroke as the ball drops after the bounce, from the
## least to the most aggressive play style (an aggressive player takes the ball earlier).
const CONTACT_HEIGHT := Vector2(0.95, 1.3)
## Highest ball (m) the AI volleys; a higher ball is let bounce.
const VOLLEY_MAX_HEIGHT: float = 2.3

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
	var trajectory: Array[TrajectoryStep] = player.ball.predict_trajectory()
	var step: TrajectoryStep = _volley_step(trajectory)
	if not step:
		var contact_height: float = lerpf(
			CONTACT_HEIGHT.x, CONTACT_HEIGHT.y, player.player_data.play_style.aggression
		)
		step = groundstroke_contact_step(
			trajectory, contact_height, _baseline_recovery_depth() + MAX_RETREAT
		)
	# The ball does not reach this side (e.g. it ends up in the net).
	if not step:
		return

	_pending_stroke = _strategy.compute_stroke(step)
	player.label_3d.modulate = _intent_color(_pending_stroke.stroke_intent)
	_log_stroke("Stroke at t=%.3f" % step.time, _pending_stroke)
	move_to_contact(step, _pending_stroke)
	_current_phase = Phase.WAITING_FOR_HIT


## Where the AI volleys the ball: at the net, or when the ball comes into the net zone out of
## the air, it steps in and takes it before the bounce if it gets there in time and the ball is
## not too high. Null if the ball is let bounce.
func _volley_step(trajectory: Array[TrajectoryStep]) -> TrajectoryStep:
	var step: TrajectoryStep = _closest_playable_step(trajectory)
	var volley_chance: bool = step != null and step.is_volley_contact() and step.is_in_net_zone()
	if not (_plays_at_net or volley_chance):
		return null
	var intercept: TrajectoryStep = _volley_intercept_step(trajectory, 1.0)
	if intercept and intercept.point.y <= VOLLEY_MAX_HEIGHT:
		return intercept
	return null


## After hitting, maybe follows a good offensive shot to the net, then covers the angles of the
## reply. An approach starts right away; otherwise the AI recovers after the follow-through.
func _on_player_ball_hit() -> void:
	var hit_stroke: Stroke = player.queued_stroke
	var landing: TrajectoryStep = _predicted_landing()
	var approaches: bool = false
	if not _plays_at_net and _is_approach_shot(hit_stroke, landing):
		var approach_chance: float = lerpf(
			NET_APPROACH_CHANCE_MIN, NET_APPROACH_CHANCE_MAX, player.stats.tactical_net_play01()
		)
		approaches = randf() < approach_chance
		_plays_at_net = approaches
		if approaches:
			DebugLogger.log(self, "Following the attack to the net")
	var depth: float = NET_POSITION_DEPTH if _plays_at_net else _recovery_depth(hit_stroke, landing)
	var recovery: Vector3 = _calculate_angle_bisector_position(hit_stroke.stroke_target, depth)
	if approaches:
		player.request_move_to(recovery)
	else:
		player.move_to_defensive_position(recovery)
	_reset_to_anticipation()


## Whether the ball just hit is a good offensive shot to follow to the net: an attack from
## inside the baseline, met in position, landing deep or wide and either fast or with the
## opponent far from where it lands.
func _is_approach_shot(hit_stroke: Stroke, landing: TrajectoryStep) -> bool:
	var inside_court: bool = (
		absf(player.global_position.z)
		<= GameConstants.COURT_LENGTH_HALF - NET_APPROACH_INSIDE_BASELINE
	)
	if not inside_court or hit_stroke.stroke_intent != AiPointContext.ShotIntent.ATTACK:
		return false
	if player.last_positioning_quality < APPROACH_MIN_POSITIONING:
		return false

	if not landing:
		return false
	var deep: bool = absf(landing.point.z) >= GameConstants.COURT_LENGTH_HALF * APPROACH_DEEP
	var wide: bool = absf(landing.point.x) >= GameConstants.COURT_WIDTH_HALF * APPROACH_WIDE
	var fast: bool = player.ball.velocity.length() >= APPROACH_MIN_SPEED
	var to_landing: Vector3 = landing.point - player.opponent.global_position
	to_landing.y = 0.0
	var stretches: bool = to_landing.length() >= APPROACH_STRETCH_DISTANCE
	return (deep or wide) and (fast or stretches)


## Where the ball just hit lands in the opponent's court; null if it does not get there.
func _predicted_landing() -> TrajectoryStep:
	for step in player.ball.predict_trajectory():
		if step.bounces > 0:
			return step if signf(step.point.z) != signf(player.global_position.z) else null
	return null


## Baseline depth (m from the net) the AI's play style recovers to.
func _baseline_recovery_depth() -> float:
	var court_position: float = player.player_data.play_style.court_position
	var shift: float = (
		court_position * (COURT_POSITION_BACK if court_position > 0.0 else COURT_POSITION_IN)
	)
	return GameConstants.COURT_LENGTH_HALF + RECOVERY_BEHIND_BASELINE + shift


## Depth (m from the net) the AI recovers to after `hit_stroke`: deeper after a weak shot the
## opponent can attack, closer in after a good attack.
func _recovery_depth(hit_stroke: Stroke, landing: TrajectoryStep) -> float:
	var depth: float = _baseline_recovery_depth()
	var weak: bool = (
		player.last_positioning_quality < WEAK_SHOT_POSITIONING
		or hit_stroke.stroke_intent == AiPointContext.ShotIntent.SAFE
		or not landing
		or absf(landing.point.z) < SHORT_SHOT_DEPTH
	)
	if weak:
		return depth + WEAK_SHOT_STEP_BACK
	if (
		hit_stroke.stroke_intent == AiPointContext.ShotIntent.ATTACK
		and player.last_positioning_quality >= APPROACH_MIN_POSITIONING
	):
		return depth - ATTACK_STEP_IN
	return depth


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
