## Drives the player AnimationTree: locomotion blending with strokes layered on top as a OneShot.
## Locomotion: the idle crossfades into the moving blend space up to walking speed. The moving
## clips are gait cycles of equal length that all start at the left foot's touchdown (see the
## Mixamo locomotion import); the blend space plays them in sync, so blending never mixes
## different steps, at the cadence of the running speed.
## Strokes: a StrokeBlend plays on a stroke clock this animator runs (the tree only seeks its
## clips to it): its speed can change at any time, and it can hold at a marker, e.g. with the
## racket taken back (`swing`) until the forward swing has to start. The blend's marker times
## (`swing`, `hit`, `toss`, ...) lie between its two clips' by its weight; each clip is played
## from its own times so that both reach every marker together. Passing a marker emits
## `stroke_marker_reached`. While the player runs during a stroke's preparation, the legs and hips
## keep running under it (the upper body keeps the stroke's turn, see TorsoTwistModifier); from
## the forward swing on, the stroke's own footwork takes over.
## The tree is advanced here, right after the clock (callback mode manual), so a marker's pose is
## on the skeleton when it is reached.
class_name PlayerAnimator
extends AnimationTree

## Emitted when the playing stroke passes one of its markers.
signal stroke_marker_reached(marker: StringName)

## Emitted when the stroke starts to fade out and locomotion takes over again.
signal stroke_finished

const HIT_MARKER: StringName = &"hit"
const TOSS_MARKER: StringName = &"toss"
## The racket is taken back the farthest: the forward swing to `hit` starts.
const SWING_MARKER: StringName = &"swing"

## Clips whose cycle time and running speed set the cadence
const WALK_ANIMATION: StringName = &"walk"
const RUN_ANIMATION: StringName = &"run"
## Moving slower than this share above the walk clip's speed is blended at it, so the blend never
## falls between clips of opposite directions.
const MIN_MOVE_BLEND_FACTOR: float = 1.1
## The locomotion follows the speed with this time constant (s), and turns its direction at
## most at LOCOMOTION_TURN_SPEED (rad/s, a little slower than the body turns), so sudden changes
## crossfade instead of popping. Speed and direction follow separately: a reversal turns the
## direction around rather than passing through standing still.
const LOCOMOTION_SMOOTHING_TIME: float = 0.08
const LOCOMOTION_TURN_SPEED: float = 6.0
## Below this speed (m/s) the locomotion takes a new direction right away
const LOCOMOTION_STANDING_SPEED: float = 0.05
## Below this speed (m/s) the player stands rather than steps: a creeping player would otherwise
## patter on the spot. The steps fade in up to walking speed.
const STEPPING_SPEED: float = 0.4
## Speeds (m/s) between which the legs of a preparing stroke change over from the stroke's stance
## to running, and the time constant (s) the legs change over with
const RUNNING_LEGS_SPEED: Vector2 = Vector2(1.0, 2.5)
const RUNNING_LEGS_TIME: float = 0.12

## Both locomotion branches: the full body and the legs running under a stroke
const _LOCOMOTION_BRANCHES: Array[String] = ["Locomotion", "LegLocomotion"]
const _RUNNING_LEGS: StringName = &"parameters/RunningLegs/blend_amount"
const _STROKE_REQUEST: StringName = &"parameters/Stroke/request"
const _STROKE_CLOCK: StringName = &"parameters/StrokeClock/scale"
const _HEIGHT_BLEND: StringName = &"parameters/HeightBlend/blend_amount"
const _LOW_SELECT: StringName = &"parameters/LowSelect/transition_request"
const _HIGH_SELECT: StringName = &"parameters/HighSelect/transition_request"
const _LOW_SEEK: StringName = &"parameters/LowSeek/seek_request"
const _HIGH_SEEK: StringName = &"parameters/HighSeek/seek_request"
const _STROKE_NODE: StringName = &"Stroke"
const _STROKE_SELECT_NODE: StringName = &"LowSelect"

## Stroke playing (also while it fades out), null when none is
var _stroke: StrokeBlend = null
## Stroke clock (s on the blend's timeline), its speed and the marker it holds at (empty: none)
var _stroke_time: float = 0.0
var _stroke_speed: float = 1.0
var _hold_marker: StringName = &""
## Whether the stroke fades out already (stroke_finished was emitted)
var _stroke_fading: bool = false
## Whether the stroke plays through to its end: its forward swing started, or it never holds
var _stroke_released: bool = false
## Share of the legs running under the stroke (see RUNNING_LEGS_SPEED)
var _running_legs: float = 0.0
## Key times (s) of the two clips and of the blend: start, markers by time, end
var _low_keys: PackedFloat32Array
var _high_keys: PackedFloat32Array
var _blend_keys: PackedFloat32Array
var _marker_names: Array[StringName] = []
## Seconds a stroke fades out over
var _fade_out_time: float
## Locomotion velocity (m/s) the animation follows, smoothed
var _locomotion_velocity: Vector2 = Vector2.ZERO
## Running speed (m/s) and gait cycles per second of the walk and the run clip
var _walk_speed: float
var _walk_cadence: float
var _run_speed: float
var _run_cadence: float
## Length (s) of the gait cycle clips
var _gait_cycle_length: float


func _ready() -> void:
	var walk: Animation = get_animation(WALK_ANIMATION)
	var run: Animation = get_animation(RUN_ANIMATION)
	_walk_speed = walk.get_meta(&"travel_speed")
	_walk_cadence = 1.0 / walk.get_meta(&"cycle_time")
	_run_speed = run.get_meta(&"travel_speed")
	_run_cadence = 1.0 / run.get_meta(&"cycle_time")
	_gait_cycle_length = walk.length
	var stroke_node: AnimationNodeOneShot = (tree_root as AnimationNodeBlendTree).get_node(
		_STROKE_NODE
	)
	_fade_out_time = stroke_node.fadeout_time
	callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	set(_STROKE_CLOCK, 0.0)
	active = true


func _process(delta: float) -> void:
	if not active:
		return
	_advance_stroke(delta)
	_update_running_legs(delta)
	advance(delta)


## Moves the locomotion toward the velocity (m/s) relative to where the body faces (x = right,
## y = forward).
func set_locomotion(velocity: Vector2, delta: float) -> void:
	var follow: float = 1.0 - exp(-delta / LOCOMOTION_SMOOTHING_TIME)
	var speed: float = lerpf(_locomotion_velocity.length(), velocity.length(), follow)
	var direction: float = _locomotion_velocity.angle()
	if _locomotion_velocity.length() < LOCOMOTION_STANDING_SPEED:
		direction = velocity.angle()
	elif velocity != Vector2.ZERO:
		var max_turn: float = LOCOMOTION_TURN_SPEED * delta
		direction += clampf(wrapf(velocity.angle() - direction, -PI, PI), -max_turn, max_turn)
	_apply_locomotion(Vector2.from_angle(direction) * speed)


func _apply_locomotion(velocity: Vector2) -> void:
	_locomotion_velocity = velocity
	var speed: float = velocity.length()
	var moving: float = clampf(inverse_lerp(STEPPING_SPEED, _walk_speed, speed), 0.0, 1.0)
	for branch in _LOCOMOTION_BRANCHES:
		set("parameters/%s/Moving/blend_amount" % branch, moving)
		set("parameters/%s/Cadence/scale" % branch, _cadence(speed) * _gait_cycle_length)
		if speed > 0.0:
			set(
				"parameters/%s/Move/blend_position" % branch,
				velocity / speed * maxf(speed, _walk_speed * MIN_MOVE_BLEND_FACTOR)
			)


## Lets the legs run as fast as the player runs, except under a stroke playing its forward swing
## and follow-through, whose footwork they follow.
func _update_running_legs(delta: float) -> void:
	var running: float = 0.0
	if not _stroke or not _stroke_released or _stroke_fading:
		running = smoothstep(
			RUNNING_LEGS_SPEED.x, RUNNING_LEGS_SPEED.y, _locomotion_velocity.length()
		)
	_running_legs = lerpf(_running_legs, running, 1.0 - exp(-delta / RUNNING_LEGS_TIME))
	set(_RUNNING_LEGS, _running_legs)


## Gait cycles per second at `speed` (m/s): from the walk's to the run's cadence between their
## speeds; faster than the run clip the cadence rises with the square root of the speed, since
## the stride lengthens as well.
func _cadence(speed: float) -> float:
	if speed > _run_speed:
		return _run_cadence * sqrt(speed / _run_speed)
	var run_share: float = clampf(inverse_lerp(_walk_speed, _run_speed, speed), 0.0, 1.0)
	return lerpf(_walk_cadence, _run_cadence, run_share)


## Whether the AnimationTree can play the given animation as a stroke.
func has_stroke_animation(animation_name: StringName) -> bool:
	var select: AnimationNodeTransition = (tree_root as AnimationNodeBlendTree).get_node(
		_STROKE_SELECT_NODE
	)
	return has_animation(animation_name) and select.find_input(animation_name) != -1


## Time (s) of `marker` on the timeline of `stroke`.
func get_marker_time(stroke: StrokeBlend, marker: StringName) -> float:
	var low: Animation = get_animation(stroke.low.animation)
	var high: Animation = get_animation(stroke.high.animation)
	assert(low.has_marker(marker), "%s has no '%s' marker" % [stroke.low.animation, marker])
	assert(high.has_marker(marker), "%s has no '%s' marker" % [stroke.high.animation, marker])
	return lerpf(low.get_marker_time(marker), high.get_marker_time(marker), stroke.weight)


## Whether `stroke` has `marker`.
func has_marker(stroke: StrokeBlend, marker: StringName) -> bool:
	return get_animation(stroke.low.animation).has_marker(marker)


## Plays `stroke` on top of locomotion from `start_time` (s on its timeline; markers before it
## do not fire) at `speed`, holding at `hold_marker` (none: plays through) until released.
func play_stroke(
	stroke: StrokeBlend, speed: float = 1.0, start_time: float = 0.0, hold_marker := &""
) -> void:
	_stroke = stroke
	_stroke_speed = speed
	_hold_marker = hold_marker
	_stroke_released = hold_marker.is_empty()
	_stroke_fading = false
	_set_stroke_keys()
	_stroke_time = start_time
	set(_LOW_SELECT, String(stroke.low.animation))
	set(_HIGH_SELECT, String(stroke.high.animation))
	set(_HEIGHT_BLEND, stroke.weight)
	set(_STROKE_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_seek_stroke()


## Changes the blend weight of the playing stroke (e.g. as the ball's height becomes clearer).
func set_stroke_weight(weight: float) -> void:
	_stroke.weight = weight
	_set_stroke_keys()
	set(_HEIGHT_BLEND, weight)


## Changes the speed of the stroke clock.
func set_stroke_speed(speed: float) -> void:
	_stroke_speed = speed


## Releases a stroke holding (or about to hold) at its hold marker, going on at `speed`.
func release_stroke(speed: float) -> void:
	_hold_marker = &""
	_stroke_released = true
	_stroke_speed = speed


## Jumps the stroke clock forward to `time` (s on the stroke's timeline); markers before it do
## not fire.
func skip_stroke_to(time: float) -> void:
	_stroke_time = maxf(_stroke_time, time)
	_seek_stroke()


## Stroke playing (also while it fades out), null when none is.
func get_stroke() -> StrokeBlend:
	return _stroke


## Time (s) on the playing stroke's timeline.
func get_stroke_time() -> float:
	return _stroke_time


## Times (s) in the playing stroke's low and high clip at the stroke clock.
func get_stroke_clip_times() -> Vector2:
	return Vector2(_clip_time(_low_keys), _clip_time(_high_keys))


## Share in [0, 1] of the legs and hips running under the stroke rather than following it.
func get_running_legs() -> float:
	return _running_legs


## Seconds until the playing stroke reaches `marker` at its current speed.
func seconds_until_marker(marker: StringName) -> float:
	return (_key_time(marker) - _stroke_time) / _stroke_speed


## Fade the current stroke out back into locomotion.
func stop_stroke() -> void:
	if not _stroke or _stroke_fading:
		return
	set(_STROKE_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_finish_stroke()


func get_snapshot() -> Dictionary:
	var stroke_snapshot: Dictionary = {}
	if _stroke and not _stroke_fading:
		stroke_snapshot = {
			"low": _stroke.low,
			"high": _stroke.high,
			"weight": _stroke.weight,
			"time": _stroke_time,
		}
	return {"locomotion": _locomotion_velocity, "stroke": stroke_snapshot}


## Reproduce a pose recorded with `get_snapshot` (used by replays).
func apply_snapshot(snapshot: Dictionary) -> void:
	_apply_locomotion(snapshot["locomotion"])
	var stroke_snapshot: Dictionary = snapshot["stroke"]
	if stroke_snapshot.is_empty():
		stop_stroke()
		return
	var stroke := StrokeBlend.new(
		stroke_snapshot["low"], stroke_snapshot["high"], stroke_snapshot["weight"]
	)
	if not stroke.is_same_swing(_stroke) or _stroke_fading:
		play_stroke(stroke, 0.0)
	elif stroke.weight != _stroke.weight:
		set_stroke_weight(stroke.weight)
	_stroke_speed = 0.0
	_stroke_time = stroke_snapshot["time"]
	_seek_stroke()


## Runs the stroke clock: fires the markers it passes, holds at the hold marker and starts the
## fade-out so that it ends with the clips.
func _advance_stroke(delta: float) -> void:
	if not _stroke:
		return
	var previous_time: float = _stroke_time
	_stroke_time += delta * _stroke_speed
	if not _hold_marker.is_empty():
		_stroke_time = minf(_stroke_time, _key_time(_hold_marker))
	var end_time: float = _blend_keys[-1]
	if _stroke_fading and _stroke_time >= end_time:
		_stroke = null
		return
	_seek_stroke()
	if _stroke_fading:
		return
	for marker in _marker_names:
		var marker_time: float = _key_time(marker)
		if previous_time < marker_time and marker_time <= _stroke_time:
			stroke_marker_reached.emit(marker)
	if _stroke and _stroke_time >= end_time - _fade_out_time:
		stop_stroke()


## Seeks both stroke clips to the stroke clock.
func _seek_stroke() -> void:
	set(_LOW_SEEK, _clip_time(_low_keys))
	set(_HIGH_SEEK, _clip_time(_high_keys))


## Time in the clip with key times `keys` at the stroke clock: between the same keys as on the
## blend's timeline.
func _clip_time(keys: PackedFloat32Array) -> float:
	for i in range(1, _blend_keys.size()):
		if _stroke_time <= _blend_keys[i] or i == _blend_keys.size() - 1:
			var share: float = inverse_lerp(_blend_keys[i - 1], _blend_keys[i], _stroke_time)
			return lerpf(keys[i - 1], keys[i], clampf(share, 0.0, 1.0))
	return keys[-1]


func _set_stroke_keys() -> void:
	var low: Animation = get_animation(_stroke.low.animation)
	var high: Animation = get_animation(_stroke.high.animation)
	_marker_names.assign(low.get_marker_names())
	var high_markers: Array[StringName] = []
	high_markers.assign(high.get_marker_names())
	assert(
		high_markers == _marker_names,
		"%s and %s have different markers" % [_stroke.low.animation, _stroke.high.animation]
	)
	_low_keys = _key_times(low)
	_high_keys = _key_times(high)
	_blend_keys = PackedFloat32Array()
	for i in _low_keys.size():
		_blend_keys.append(lerpf(_low_keys[i], _high_keys[i], _stroke.weight))


## Start, marker and end times (s) of `animation`, in the order of `_marker_names` (by time).
func _key_times(animation: Animation) -> PackedFloat32Array:
	var keys := PackedFloat32Array([0.0])
	for marker in _marker_names:
		keys.append(animation.get_marker_time(marker))
	keys.append(animation.length)
	return keys


## Time (s) of `marker` on the playing stroke's timeline.
func _key_time(marker: StringName) -> float:
	return _blend_keys[_marker_names.find(marker) + 1]


func _finish_stroke() -> void:
	_stroke_fading = true
	_hold_marker = &""
	_stroke_speed = maxf(_stroke_speed, 1.0)
	stroke_finished.emit()
