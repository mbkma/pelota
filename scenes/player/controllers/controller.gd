## Base class for player control (human/AI): decides movement and strokes for its player.
@abstract class_name Controller
extends Node

## Height (m) at which a groundstroke is comfortably met as the ball drops after the bounce,
## and how far behind the baseline (m) a player retreats at most for a deep, high ball (beyond
## it the ball is taken higher), used for the ideal position.
const IDEAL_CONTACT_HEIGHT: float = 1.1
const MAX_RETREAT_BEHIND_BASELINE: float = 3.0
## Time (s) a player wants to be in place before a groundstroke, to set for the swing
const GROUNDSTROKE_SETUP_TIME: float = 0.25
## Lowest ball height (m) a stroke can still reach
const MIN_CONTACT_HEIGHT: float = 0.2
## Farthest (m) a volleying player steps in toward the net to cut the ball off
const VOLLEY_STEP_IN: float = 1.5
## Time (s) a volleying player wants to be in place before contact, to set for the punch
const VOLLEY_SETUP_TIME: float = 0.2

## Player this controller drives
var player: Player


func _init(controlled_player: Player) -> void:
	player = controlled_player


## Update controller state - called by Player each frame
@abstract func update(delta: float) -> void

## Request the controller to initiate a serve
@abstract func request_serve() -> void

## Desired movement direction; its length is the share of the top speed.
@abstract func get_move_direction() -> Vector3

## Stroke the controller wants to play, null if none.
@abstract func get_stroke() -> Stroke


func ball_changed(_ball: Ball) -> void:
	pass


## Lifecycle callback from the player's lifecycle bus (serve/rally/point phases)
func on_lifecycle_phase_changed(_current_phase: MatchLifecycleBus.Phase) -> void:
	pass


## Aim marker position; null hides the marker.
func get_aim_marker_position() -> Variant:
	return null


## Where the player should stand to meet the incoming ball, shown by the ideal position
## marker; null hides the marker.
func get_ideal_position() -> Variant:
	return null


## Radius (m) in which the aimed stroke may land, shown by the aim marker
func get_aim_marker_radius() -> float:
	return BallAimMarker.DEFAULT_RADIUS


## Whether the aim marker should be highlighted (e.g. perfectly timed stroke)
func is_aim_marker_highlighted() -> bool:
	return false


## Moves the player to where the racket contact point of `stroke` meets the ball at `step`.
func move_to_contact(step: TrajectoryStep, stroke: Stroke) -> void:
	player.request_move_to(position_for_contact(step, stroke))


## Where the player has to stand so the racket contact point of `stroke` meets the ball at
## `step`.
func position_for_contact(step: TrajectoryStep, stroke: Stroke) -> Vector3:
	var contact_to_body: Vector3 = (
		player.model.get_racket_contact_point(stroke) - player.global_position
	)
	contact_to_body.y = 0.0
	var body_position: Vector3 = step.point - contact_to_body
	body_position.y = player.position.y
	return body_position


## Best point to meet the incoming ball: a volley if the ball can be taken before the bounce
## in the net zone, otherwise a groundstroke after the bounce (see
## groundstroke_contact_step).
func get_ideal_contact_step() -> TrajectoryStep:
	var trajectory: Array[TrajectoryStep] = player.ball.predict_trajectory()
	var closest_step: TrajectoryStep = _closest_playable_step(trajectory)
	if closest_step and closest_step.is_volley_contact() and closest_step.is_in_net_zone():
		var intercept: TrajectoryStep = _volley_intercept_step(trajectory, 1.0)
		return intercept if intercept else closest_step
	return groundstroke_contact_step(
		trajectory,
		IDEAL_CONTACT_HEIGHT,
		GameConstants.COURT_LENGTH_HALF + MAX_RETREAT_BEHIND_BASELINE
	)


## Where a player meets the ball after the bounce: as it drops to `contact_height` after the
## apex (at the apex of a lower bounce), so the player moves in for a short ball and back for a
## deep, high one. The player retreats no farther than `max_depth` (m from the net) and takes
## the ball higher there. If the player cannot get there and set in time, it takes the ball
## at the nearest point along the flight it can get to (earlier on the rise, or later and
## lower); if there is none, where it is least late. Null if the ball does not bounce on this
## side.
func groundstroke_contact_step(
	trajectory: Array[TrajectoryStep], contact_height: float, max_depth: float
) -> TrajectoryStep:
	var side: float = signf(player.global_position.z)
	var candidates: Array[TrajectoryStep] = []
	var preferred_index: int = -1
	var previous_y: float = -INF
	var apex_passed: bool = false
	for step in trajectory:
		if step.bounces > 1:
			break
		if step.bounces == 0 or signf(step.point.z) != side or step.point.y < MIN_CONTACT_HEIGHT:
			continue
		if absf(step.point.z) > max_depth and not candidates.is_empty():
			break
		candidates.append(step)
		apex_passed = apex_passed or step.point.y < previous_y
		previous_y = step.point.y
		if preferred_index < 0 and apex_passed and step.point.y <= contact_height:
			preferred_index = candidates.size() - 1
	if candidates.is_empty():
		return null
	if preferred_index < 0:
		preferred_index = candidates.size() - 1

	var best: TrajectoryStep = null
	var best_offset: int = 0
	var least_late: TrajectoryStep = null
	var least_lateness: float = INF
	for i in candidates.size():
		var step: TrajectoryStep = candidates[i]
		var reach_time: float = player.time_to_reach(ideal_position_for_step(step))
		var lateness: float = reach_time - (step.time - GROUNDSTROKE_SETUP_TIME)
		if lateness <= 0.0 and (not best or absi(i - preferred_index) < best_offset):
			best = step
			best_offset = absi(i - preferred_index)
		if lateness < least_lateness:
			least_late = step
			least_lateness = lateness
	return best if best else least_late


## Where the player should stand to meet the ball at `step` with a forehand or backhand
## (whichever side the ball is on).
func ideal_position_for_step(step: TrajectoryStep) -> Vector3:
	var stroke := Stroke.new()
	stroke.step = step
	var is_forehand: bool = (step.point - player.global_position).dot(player.global_basis.x) > 0.0
	if step.is_volley_contact():
		stroke.stroke_type = (
			Stroke.StrokeType.FOREHAND_VOLLEY if is_forehand else Stroke.StrokeType.BACKHAND_VOLLEY
		)
	else:
		stroke.stroke_type = (
			Stroke.StrokeType.FOREHAND if is_forehand else Stroke.StrokeType.BACKHAND
		)
	return position_for_contact(step, stroke)


## Where a player in the net zone volleys the incoming ball, running at `speed_factor` of its
## top speed: like a net player cutting the ball off, it steps in and meets the ball as early as
## it can be there and set, at most VOLLEY_STEP_IN closer to the net. Null if the ball cannot be
## volleyed in time.
func get_volley_intercept_step(speed_factor: float) -> TrajectoryStep:
	return _volley_intercept_step(player.ball.predict_trajectory(), speed_factor)


func _volley_intercept_step(
	trajectory: Array[TrajectoryStep], speed_factor: float
) -> TrajectoryStep:
	var side: float = signf(player.global_position.z)
	var closest_depth: float = maxf(
		absf(player.global_position.z) - VOLLEY_STEP_IN, GameConstants.VOLLEY_MIN_NET_DISTANCE
	)
	for step in trajectory:
		if not step.is_volley_contact():
			break
		if signf(step.point.z) != side or not step.is_in_net_zone():
			continue
		if step.point.y < MIN_CONTACT_HEIGHT:
			continue
		var body_position: Vector3 = ideal_position_for_step(step)
		if absf(body_position.z) < closest_depth:
			continue
		if player.time_to_reach(body_position, speed_factor) <= step.time - VOLLEY_SETUP_TIME:
			return step
	return null


## Playable trajectory step (before the second bounce, high enough to reach) closest to the
## player by Z distance. A ball dying short of the player (e.g. a drop shot) is met at the last
## step it can still be played.
func get_closest_trajectory_step() -> TrajectoryStep:
	return _closest_playable_step(player.ball.predict_trajectory())


func _closest_playable_step(trajectory: Array[TrajectoryStep]) -> TrajectoryStep:
	var closest_step: TrajectoryStep = null
	for step in trajectory:
		if step.bounces > 1:
			break
		if step.point.y < MIN_CONTACT_HEIGHT:
			continue
		if not closest_step or _z_distance(step) < _z_distance(closest_step):
			closest_step = step
	return closest_step


func _z_distance(step: TrajectoryStep) -> float:
	return absf(step.point.z - player.global_position.z)
