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


func _ready() -> void:
	var p = get_parent()
	if p is Player:
		player = get_parent()
		animation_tree.active = true


func compute_animation_speed(anim_time_to_contact: float, real_time_to_contact: float) -> float:
	# prevent division by zero
	if real_time_to_contact <= 0.01:
		return 1.0
	Loggie.msg("[Model] animation_speed ratio: ", anim_time_to_contact / real_time_to_contact).debug()
	return anim_time_to_contact / real_time_to_contact


## Called from animation timeline to spawn the ball (forwarded to player)
func _from_anim_spawn_ball() -> void:
	player.from_anim_spawn_ball()

## Called from animation timeline to hit the serve (forwarded to player)
func from_anim_hit_serve() -> void:
	player.from_anim_hit_serve()

## Called from animation timeline when stroke animation finishes
func _from_anim_stroke_finished() -> void:
	stroke_animation_finished.emit()

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
		playback_speed = compute_animation_speed(17.0 / 30.0, stroke.step.time)
		playback_speed = clamp(playback_speed, 0.5, 3)
		Loggie.msg("[Model] playback_speed: ", playback_speed, " time: ", stroke.step.time).debug()

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
	var animation_name: String
	match stroke.stroke_type:
		stroke.StrokeType.FOREHAND:
			animation_name = "forehand"
		stroke.StrokeType.SERVE:
			animation_name = "serve"
		stroke.StrokeType.BACKHAND:
			animation_name = "backhand"
			animation_tree["parameters/stroke/backhand/blend_position"] = compute_stroke_blend_position(stroke)
			Loggie.msg("[Model] backhand blend position: ", animation_tree["parameters/stroke/backhand/blend_position"]).debug()
		stroke.StrokeType.BACKHAND_SLICE:
			animation_name = "backhand_slice"
		stroke.StrokeType.BACKHAND_DROP_SHOT:
			animation_name = "backhand_slice"
		_:
			push_warning("Stroke animation ", stroke.stroke_type, " not available!")

	animation_tree["parameters/stroke/Transition/transition_request"] = animation_name
