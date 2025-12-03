## Player model with animations, skeleton points, and stroke handling
class_name Model
extends Node3D

## Emitted when stroke animation finishes
signal stroke_animation_finished

## Emitted when recovery animation finishes
signal recovery_animation_finished

## Reference to parent player
var player: Player

## Track current stroke for animation completion
var _current_stroke: Stroke

## Track last animation state for detecting transitions
var _last_state: String = ""

## Track if stroke animation finished signal was already emitted
var _stroke_finished_emitted: bool = false

@onready var points: Node3D = $Points
@onready var serve_point: Vector3 = points.get_node("BallServePoint").position
@onready var toss_point: Vector3 = points.get_node("BallTossPoint").position
@onready var forehand_up_point: Vector3 = points.get_node("ForehandUpPoint").position
@onready var forehand_point: Marker3D = $Points/ForehandPoint
@onready var forehand_down_point: Vector3 = points.get_node("ForehandDownPoint").position
@onready var backhand_up_point: Vector3 = points.get_node("BackhandUpPoint").position
@onready var backhand_down_point: Vector3 = points.get_node("BackhandDownPoint").position
@onready var backhandslice_up_point: Vector3 = points.get_node("BackhandSliceUpPoint").position
@onready var backhandslice_down_point: Vector3 = points.get_node("BackhandSliceDownPoint").position
@onready var backhand_point: Marker3D = $Points/BackhandPoint
@onready var backhand_slice_point: Marker3D = $Points/BackhandSlicePoint

@onready var racket_forehand: Area3D = $RacketForehand
@onready var racket_backhand: Area3D = $RacketBackhand

@export var animation_tree: AnimationTree
@onready var _playback: AnimationNodeStateMachinePlayback = (
	animation_tree.get("parameters/playback")
)

## Reference to the AnimationPlayer that drives the animation tree
@onready var _animation_player: AnimationPlayer = animation_tree.get_node(animation_tree.anim_player)

## Mapping from stroke type to animation name for lookup
var _stroke_animation_names: Dictionary = {
	Stroke.StrokeType.FOREHAND: "g_forehand",
	Stroke.StrokeType.BACKHAND: "g_backhand",
	Stroke.StrokeType.BACKHAND_SLICE: "g_backhand_slice",
	Stroke.StrokeType.BACKHAND_DROP_SHOT: "g_backhand_slice",
	Stroke.StrokeType.SERVE: "g_serve",
	Stroke.StrokeType.VOLLEY: "g_volley",
	Stroke.StrokeType.FOREHAND_DROP_SHOT: "g_forehand",
}


func _ready() -> void:
	var p = get_parent()
	if p is Player:
		player = get_parent()
		animation_tree.active = true


func _process(_delta: float) -> void:
	if not _playback:
		return

	var current_state: String = _playback.get_current_node()

	# Detect when we transition away from stroke state
	if _last_state == "stroke" and current_state != "stroke" and not _stroke_finished_emitted:
		_stroke_finished_emitted = true
		stroke_animation_finished.emit()

	# Reset flag when entering stroke state
	if current_state == "stroke":
		_stroke_finished_emitted = false

	_last_state = current_state


## Animation Timing API
########################
##
## Timing data is fetched at runtime from animation markers and lengths.
## Each stroke animation should have a "hit" marker indicating when the racket contacts the ball.

## Get the time in seconds when the racket contacts the ball for a given stroke
## Queries the "hit" marker from the animation
## Returns the marker time, or 0.4s default if not found
func get_animation_hit_frame_time(stroke_type: Stroke.StrokeType) -> float:
	var anim_name: String = _stroke_animation_names.get(stroke_type, "")
	var animation: Animation = _animation_player.get_animation(anim_name)

	# Query the "hit" marker time directly
	return animation.get_marker_time("hit")

## Get total animation length in seconds for a given stroke
## Queries animation length directly from the animation resource
func get_animation_length(stroke_type: Stroke.StrokeType) -> float:
	var anim_name: String = _stroke_animation_names.get(stroke_type, "")
	var animation: Animation = _animation_player.get_animation(anim_name)
	return animation.length

## Get timing data dictionary for a stroke type
## Combines animation length and hit marker time
func get_animation_timing_data(stroke_type: Stroke.StrokeType) -> Dictionary:
	var length: float = get_animation_length(stroke_type)
	var hit_time: float = get_animation_hit_frame_time(stroke_type)
	return {"length": length, "hit_frame_time": hit_time}


func compute_animation_speed(anim_time_to_contact: float, real_time_to_contact: float) -> float:
	# prevent division by zero
	if real_time_to_contact <= 0.01:
		return 1.0
	Loggie.msg("animation_speed ratio: ", anim_time_to_contact / real_time_to_contact).info()
	return anim_time_to_contact / real_time_to_contact


## Called from animation timeline to spawn the ball (forwarded to player)
func _from_anim_spawn_ball() -> void:
	player.from_anim_spawn_ball()

## Called from animation timeline to hit the serve (forwarded to player)
func from_anim_hit_serve() -> void:
	player.from_anim_hit_serve()

func compute_stroke_blend_position(stroke: Stroke) -> float:
	match stroke.stroke_type:
		stroke.StrokeType.FOREHAND:
			return ((stroke.step.point.y - forehand_down_point.y) /
					(forehand_up_point.y - forehand_down_point.y))
		stroke.StrokeType.BACKHAND:
			return ((stroke.step.point.y - 0.4 - backhand_down_point.y) /
					(backhand_up_point.y - backhand_down_point.y))
		_:
			return 0.5


## Animation API
################

## Play idle animation
func play_idle() -> void:
	_playback.travel("move")
	animation_tree["parameters/move/blend_position"] = Vector2.ZERO


## Play run animation in given direction
func play_run(direction: Vector3) -> void:
	# Transform world-space direction to player's local space
	var local_direction: Vector3 = player.global_transform.basis.inverse() * direction
	var dir: Vector2 = Vector2(local_direction.x, -local_direction.z)
	animation_tree["parameters/move/blend_position"] = dir
	_playback.travel("move")


## Play stroke animation for given stroke
func play_stroke(stroke: Stroke) -> void:
	_current_stroke = stroke
	var playback_speed = 1.0

	# Only compute speed from step data if available (regular strokes have step, serves don't)
	if stroke.step:
		# Use dynamic hit frame time from animation marker instead of hardcoded value
		var animation_hit_time: float = get_animation_hit_frame_time(stroke.stroke_type)
		playback_speed = compute_animation_speed(animation_hit_time, stroke.step.time)
		#playback_speed = clamp(playback_speed, 0.5, 3)
		Loggie.msg("playback_speed: ", playback_speed, " time: ", stroke.step.time).info()

	animation_tree.set("parameters/stroke/TimeScale/scale", playback_speed)
	_set_stroke_animation(stroke)
	_playback.travel("stroke")


## Play recovery animation after stroke finishes
func play_recovery() -> void:
	_playback.travel("move")
	animation_tree["parameters/move/blend_position"] = Vector2.ZERO
	recovery_animation_finished.emit()


## Internal helper to set stroke animation type and parameters
func _set_stroke_animation(stroke: Stroke) -> void:
	var animation_name: String = _stroke_animation_names.get(stroke.stroke_type, "")

	if animation_name.is_empty():
		push_warning("Stroke animation ", stroke.stroke_type, " not available!")
		return

	# Handle backhand-specific blend position
	if stroke.stroke_type == Stroke.StrokeType.BACKHAND:
		animation_tree["parameters/stroke/backhand/blend_position"] = compute_stroke_blend_position(stroke)
		Loggie.msg("backhand blend position: ", animation_tree["parameters/stroke/backhand/blend_position"]).info()

	animation_tree["parameters/stroke/Transition/transition_request"] = animation_name
