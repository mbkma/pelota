## Drives the player AnimationTree: locomotion blending with strokes layered on top as a OneShot.
## Stroke timing comes from native animation markers (`hit`, `toss`, ...), which are
## re-emitted as `stroke_marker_reached` while the stroke plays.
## Locomotion: the idle crossfades into the moving blend space up to walking speed. The moving
## clips are gait cycles of equal length that all start at the left foot's touchdown (see the
## Mixamo locomotion import); the blend space plays them in sync, so blending never mixes
## different steps, at the cadence of the running speed.
class_name PlayerAnimator
extends AnimationTree

## Emitted when the playing stroke passes one of its animation markers.
signal stroke_marker_reached(marker: StringName)

## Emitted when the stroke OneShot has finished and locomotion is back in control.
signal stroke_finished

const HIT_MARKER: StringName = &"hit"
const TOSS_MARKER: StringName = &"toss"

## Clips whose cycle time and running speed set the cadence
const WALK_ANIMATION: StringName = &"g_mixamo_walk"
const RUN_ANIMATION: StringName = &"g_mixamo_run"
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

const _MOVE_BLEND: StringName = &"parameters/Locomotion/Move/blend_position"
const _MOVE_CADENCE: StringName = &"parameters/Locomotion/Cadence/scale"
const _MOVING_AMOUNT: StringName = &"parameters/Locomotion/Moving/blend_amount"
const _STROKE_REQUEST: StringName = &"parameters/Stroke/request"
const _STROKE_ACTIVE: StringName = &"parameters/Stroke/active"
const _STROKE_SELECT: StringName = &"parameters/StrokeSelect/transition_request"
const _STROKE_POSITION: StringName = &"parameters/StrokeSelect/current_position"
const _STROKE_SEEK: StringName = &"parameters/StrokeSeek/seek_request"
const _STROKE_SPEED: StringName = &"parameters/StrokeSpeed/scale"
const _STROKE_SELECT_NODE: StringName = &"StrokeSelect"

## Animation of the stroke currently playing, empty when none is playing.
var _stroke_animation: StringName = &""
## Clip position seen at the previous update, used to detect marker crossings.
var _stroke_position: float = -1.0
## True once the OneShot has reported active for the current stroke.
var _stroke_running: bool = false
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
	mixer_applied.connect(_on_mixer_applied)
	var walk: Animation = get_animation(WALK_ANIMATION)
	var run: Animation = get_animation(RUN_ANIMATION)
	_walk_speed = walk.get_meta(&"travel_speed")
	_walk_cadence = 1.0 / walk.get_meta(&"cycle_time")
	_run_speed = run.get_meta(&"travel_speed")
	_run_cadence = 1.0 / run.get_meta(&"cycle_time")
	_gait_cycle_length = walk.length
	active = true


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
	set(_MOVING_AMOUNT, clampf(speed / _walk_speed, 0.0, 1.0))
	set(_MOVE_CADENCE, _cadence(speed) * _gait_cycle_length)
	if speed > 0.0:
		set(_MOVE_BLEND, velocity / speed * maxf(speed, _walk_speed * MIN_MOVE_BLEND_FACTOR))


## Gait cycles per second at `speed` (m/s): from the walk's to the run's cadence between their
## speeds; faster than the run clip the cadence rises with the square root of the speed, since
## the stride lengthens as well.
func _cadence(speed: float) -> float:
	if speed > _run_speed:
		return _run_cadence * sqrt(speed / _run_speed)
	var run_share: float = clampf(inverse_lerp(_walk_speed, _run_speed, speed), 0.0, 1.0)
	return lerpf(_walk_cadence, _run_cadence, run_share)


## Time in seconds of a marker in the given animation.
func get_marker_time(animation_name: StringName, marker: StringName) -> float:
	var animation: Animation = get_animation(animation_name)
	assert(animation.has_marker(marker), "%s has no '%s' marker" % [animation_name, marker])
	return animation.get_marker_time(marker)


## Whether the AnimationTree can play the given animation as a stroke.
func has_stroke_animation(animation_name: StringName) -> bool:
	var select: AnimationNodeTransition = (tree_root as AnimationNodeBlendTree).get_node(
		_STROKE_SELECT_NODE
	)
	return has_animation(animation_name) and select.find_input(animation_name) != -1


## Play a stroke animation on top of locomotion. `speed` scales the stroke playback rate;
## `start_time` (s) skips the start of the clip, its markers before that do not fire.
func play_stroke(animation_name: StringName, speed: float = 1.0, start_time: float = 0.0) -> void:
	_stroke_animation = animation_name
	_stroke_position = start_time if start_time > 0.0 else -1.0
	_stroke_running = false
	set(_STROKE_SELECT, String(animation_name))
	set(_STROKE_SPEED, speed)
	set(_STROKE_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if start_time > 0.0:
		set(_STROKE_SEEK, start_time)


## Fade the current stroke out back into locomotion.
func stop_stroke() -> void:
	if _stroke_animation.is_empty():
		return
	set(_STROKE_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_finish_stroke()


func get_snapshot() -> Dictionary:
	return {
		"locomotion": _locomotion_velocity,
		"stroke_animation": _stroke_animation,
		"stroke_position": maxf(_stroke_position, 0.0),
	}


## Reproduce a pose recorded with `get_snapshot` (used by replays).
func apply_snapshot(snapshot: Dictionary) -> void:
	_apply_locomotion(snapshot["locomotion"])

	var animation_name: StringName = snapshot["stroke_animation"]
	if animation_name.is_empty():
		stop_stroke()
		return

	if animation_name != _stroke_animation:
		play_stroke(animation_name)
	set(_STROKE_SEEK, snapshot["stroke_position"])


func _on_mixer_applied() -> void:
	if _stroke_animation.is_empty():
		return

	if not get(_STROKE_ACTIVE):
		if _stroke_running:
			_finish_stroke()
		return

	_stroke_running = true
	var position: float = get(_STROKE_POSITION)
	var animation: Animation = get_animation(_stroke_animation)
	for marker in animation.get_marker_names():
		var marker_time: float = animation.get_marker_time(marker)
		if _stroke_position < marker_time and marker_time <= position:
			stroke_marker_reached.emit(marker)
	_stroke_position = position


func _finish_stroke() -> void:
	_stroke_animation = &""
	_stroke_position = -1.0
	_stroke_running = false
	stroke_finished.emit()
