## Drives the player AnimationTree: locomotion blending with strokes layered on top as a OneShot.
## Stroke timing comes from native animation markers (`hit`, `toss`, ...), which are
## re-emitted as `stroke_marker_reached` while the stroke plays.
class_name PlayerAnimator
extends AnimationTree

## Emitted when the playing stroke passes one of its animation markers.
signal stroke_marker_reached(marker: StringName)

## Emitted when the stroke OneShot has finished and locomotion is back in control.
signal stroke_finished

const HIT_MARKER: StringName = &"hit"
const TOSS_MARKER: StringName = &"toss"

const _LOCOMOTION_BLEND: StringName = &"parameters/Locomotion/blend_position"
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


func _ready() -> void:
	mixer_applied.connect(_on_mixer_applied)
	active = true


## Set the locomotion blend position (x = right, y = forward, length 1 = full run).
func set_locomotion(blend: Vector2) -> void:
	set(_LOCOMOTION_BLEND, blend)


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
func play_stroke(
	animation_name: StringName, speed: float = 1.0, start_time: float = 0.0
) -> void:
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
		"locomotion": get(_LOCOMOTION_BLEND),
		"stroke_animation": _stroke_animation,
		"stroke_position": maxf(_stroke_position, 0.0),
	}


## Reproduce a pose recorded with `get_snapshot` (used by replays).
func apply_snapshot(snapshot: Dictionary) -> void:
	set(_LOCOMOTION_BLEND, snapshot["locomotion"])

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
