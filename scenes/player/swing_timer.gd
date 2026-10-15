## Times a stroke's swing so that its `hit` marker meets the ball. The swing prepares early: up to
## PREPARATION_LEAD seconds before it would have to start at its natural speed, it takes the racket
## back to its `swing` marker and holds it there. The forward swing from `swing` to `hit` then
## starts when the ball is that far away, and plays at its natural speed. When the ball leaves less
## time, the whole take-back plays faster, up to MAX_PREPARATION_SPEED, and only a ball leaving
## even less time starts it part of the way through. Only a ball that leaves less time than the
## forward swing takes speeds the forward swing up (at most at the player's max speed) and, when
## even that is too slow, starts it part of the way through.
## A ball whose height changes while the swing prepares moves it to the clips for that height,
## as far through as it was; another stroke (e.g. a backhand instead of a forehand) prepares
## anew.
class_name SwingTimer
extends RefCounted

## Seconds the preparation may start before the swing would have to start at its natural speed
const PREPARATION_LEAD: float = 0.6
## Fastest the preparation (the take-back) plays; a preparation that would have to be faster starts
## later in the clip instead, cutting the take-back short.
const MAX_PREPARATION_SPEED: float = 3.0

## Swing preparing or swinging, null while there is none
var swing: StrokeBlend = null

var _animator: PlayerAnimator
## Fastest the swing plays to reach the ball in time
var _max_speed: float
## Whether the forward swing has started (playing through to the follow-through)
var _released: bool = false
## Seconds until the tossed ball of a prepared serve reaches its contact point; INF before the toss
var _toss_time_left: float = INF


func _init(animator: PlayerAnimator, max_speed: float) -> void:
	_animator = animator
	_max_speed = max_speed


func is_swinging() -> bool:
	return swing != null


## Whether the forward swing toward the ball has started.
func is_released() -> bool:
	return _released


## Prepares, holds or releases the swing `candidate` for a ball reaching its contact point in
## `time_to_contact` seconds: starts preparing it when due, takes over a changed contact height
## while preparing, or prepares a different swing (e.g. a backhand instead of a forehand).
func update(candidate: StrokeBlend, time_to_contact: float) -> void:
	if _released:
		return
	if swing and not candidate.is_same_swing(swing):
		if candidate.is_same_stroke(swing):
			_animator.change_stroke(candidate)
			swing = candidate
		else:
			_animator.stop_stroke()
			swing = null
	if not swing:
		var lead_time: float = (
			_animator.get_marker_time(candidate, PlayerAnimator.HIT_MARKER) + PREPARATION_LEAD
		)
		if time_to_contact > lead_time:
			return
		swing = candidate
		_start_preparation(time_to_contact)
		return
	if candidate.weight != swing.weight:
		_animator.set_stroke_weight(candidate.weight)
	_pace(time_to_contact)


## Prepares the serve `stroke` from its start at its natural speed; it holds at its `swing`
## marker (the trophy position) until its tossed ball has fallen to one forward swing away (see
## toss and update_serve).
func prepare_serve(stroke: StrokeBlend) -> void:
	swing = stroke
	_released = false
	_toss_time_left = INF
	_animator.play_stroke(stroke, 1.0, 0.0, PlayerAnimator.SWING_MARKER)


## The ball of the prepared serve is tossed and reaches its contact point in `flight_time` seconds.
func toss(flight_time: float) -> void:
	_toss_time_left = flight_time


## Times the prepared serve by its toss over `delta` seconds. Returns the seconds until its ball
## reaches the contact point, INF before the toss.
func update_serve(delta: float) -> float:
	if _toss_time_left == INF:
		return INF
	_toss_time_left -= delta
	update(swing, _toss_time_left)
	return _toss_time_left


## Drops the swing: a swing still preparing fades out, a forward swing plays its follow-through.
func cancel() -> void:
	if swing and not _released:
		_animator.stop_stroke()
	swing = null
	_released = false
	_toss_time_left = INF


## Starts preparing so that the preparation is done when the forward swing has to start, at most
## at MAX_PREPARATION_SPEED from as far into the clip as needed.
func _start_preparation(time_to_contact: float) -> void:
	var swing_time: float = _animator.get_marker_time(swing, PlayerAnimator.SWING_MARKER)
	var preparation_time: float = time_to_contact - _forward_time()
	if preparation_time <= 0.0:
		_release_late(time_to_contact)
		return
	var start_time: float = maxf(swing_time - preparation_time * MAX_PREPARATION_SPEED, 0.0)
	_animator.play_stroke(swing, 1.0, start_time, PlayerAnimator.SWING_MARKER)
	_pace(time_to_contact)


## Prepares at least at the natural speed, faster when the preparation would not be done by the
## time the forward swing has to start; releases the forward swing then.
func _pace(time_to_contact: float) -> void:
	var forward_time: float = _forward_time()
	if time_to_contact <= forward_time:
		_release(time_to_contact)
		return
	var swing_time: float = _animator.get_marker_time(swing, PlayerAnimator.SWING_MARKER)
	var preparation_left: float = time_to_contact - forward_time
	var time: float = _animator.get_stroke_time()
	_animator.set_stroke_speed(
		clampf((swing_time - time) / preparation_left, 1.0, MAX_PREPARATION_SPEED)
	)


## Starts the forward swing so that it reaches `hit` in `time_to_contact` seconds.
func _release(time_to_contact: float) -> void:
	var hit_time: float = _animator.get_marker_time(swing, PlayerAnimator.HIT_MARKER)
	var time: float = maxf(_animator.get_stroke_time(), hit_time - time_to_contact * _max_speed)
	_animator.skip_stroke_to(time)
	_released = true
	_animator.release_stroke(_speed_to_hit(time, time_to_contact))


## Swings at once for a ball that leaves no time to prepare: from as early as the swing can still
## reach `hit` in `time_to_contact` seconds.
func _release_late(time_to_contact: float) -> void:
	var hit_time: float = _animator.get_marker_time(swing, PlayerAnimator.HIT_MARKER)
	var start_time: float = maxf(hit_time - time_to_contact * _max_speed, 0.0)
	_released = true
	_animator.play_stroke(swing, _speed_to_hit(start_time, time_to_contact), start_time)


## Speed (at least the natural one) at which the swing gets from `time` to `hit` in
## `time_to_contact` seconds.
func _speed_to_hit(time: float, time_to_contact: float) -> float:
	var hit_time: float = _animator.get_marker_time(swing, PlayerAnimator.HIT_MARKER)
	return clampf((hit_time - time) / maxf(time_to_contact, 0.001), 1.0, _max_speed)


## Seconds the forward swing from `swing` to `hit` takes at its natural speed.
func _forward_time() -> float:
	return (
		_animator.get_marker_time(swing, PlayerAnimator.HIT_MARKER)
		- _animator.get_marker_time(swing, PlayerAnimator.SWING_MARKER)
	)
