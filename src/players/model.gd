## Player model with animations, skeleton points, and stroke handling
class_name Model
extends Node3D

enum States { IDLE, MOVE, STROKE }

## Reference to parent player
var player: Player

@onready var points: Node3D = $Points
@onready var serve_point: Vector3 = points.get_node("BallServePoint").position
@onready var toss_point: Vector3 = points.get_node("BallTossPoint").position
@onready var forehand_up_point: Vector3 = points.get_node("ForehandUpPoint").position
@onready var forehand_down_point: Vector3 = points.get_node("ForehandDownPoint").position
@onready var backhand_up_point: Vector3 = points.get_node("BackhandUpPoint").position
@onready var backhand_down_point: Vector3 = points.get_node("BackhandDownPoint").position
@onready var backhandslice_up_point: Vector3 = points.get_node("BackhandSliceUpPoint").position
@onready var backhandslice_down_point: Vector3 = points.get_node("BackhandSliceDownPoint").position

@onready var racket_forehand: Area3D = $RacketForehand
@onready var racket_backhand: Area3D = $RacketBackhand

## Movement animation resources
var _movement_animations: Dictionary[String, Object] = {
	"crossover_right": preload("res://src/players/anim_crossover_right.tres")
}

## Stroke animation resources
var _stroke_animations: Dictionary[String, Object] = {
	"forehand": preload("res://src/players/forehand_anim.tres")
}

## Whether a stroke is currently active
var _stroke_active: bool = false

@export var animation_tree: AnimationTree
@onready var _playback: AnimationNodeStateMachinePlayback = (
	animation_tree.get("parameters/playback")
)


func _ready() -> void:
	player = get_parent()
	animation_tree.active = true


## Get movement speed factor from animation playback
func get_move_speed_factor() -> float:
	var current_time: float = _playback.get_current_play_position()
	var current_animation: String = _playback.get_current_node()
	var current_length: float = _playback.get_current_length()
	var w: float = 1.0
	if current_animation == "g_right":
		w = _movement_animations["crossover_right"].sample(current_time / current_length)

	return w


## Set movement animation direction based on world-space input
func set_move_direction(direction: Vector3) -> void:
	# Transform world-space direction to player's local space for correct animation
	# This ensures the animation always plays in the correct direction regardless of player orientation
	var local_direction: Vector3 = player.global_transform.basis.inverse() * direction
	var dir: Vector2 = Vector2(local_direction.x, -local_direction.z)
	animation_tree["parameters/move/blend_position"] = dir


## Get stroke blend position for smooth animation blending
func get_stroke_blend_position(_stroke_id: int, stroke_pos: Vector3) -> Vector3:
	var point_down: Vector3 = Vector3.ZERO
	var point_up: Vector3 = Vector3.ZERO

	return (stroke_pos - point_down) / (point_up - point_down)


## Play stroke animation with proper timing
func play_stroke_animation(stroke: Stroke) -> void:
	var animation_hit_time: float = GameConstants.ANIMATION_HIT_TIME
	if stroke.stroke_type == Stroke.StrokeType.FOREHAND:
		animation_hit_time = _stroke_animations["forehand"].hit_zone[0]

	var t: float = max(0, stroke.step.time - animation_hit_time)
	if t > 0:
		await get_tree().create_timer(t).timeout

	transition_to(States.STROKE)
	set_stroke(stroke)


## Set stroke animation type based on stroke
func set_stroke(stroke: Stroke) -> void:
	var animation_name: String
	match stroke.stroke_type:
		stroke.StrokeType.FOREHAND:
			animation_name = "forehand"
		stroke.StrokeType.SERVE:
			animation_name = "serve"
		stroke.StrokeType.BACKHAND:
			animation_name = "backhand"
		stroke.StrokeType.BACKHAND_SLICE:
			animation_name = "backhand"
		_:
			push_error("Stroke animation ", stroke.stroke_type, " not available!")
			return

	animation_tree["parameters/stroke/Transition/transition_request"] = animation_name


## Transition to animation state
func transition_to(state_id: int) -> void:
	match state_id:
		States.IDLE:
			_playback.travel("move")
		States.MOVE:
			_playback.travel("move")
		States.STROKE:
			_playback.travel("stroke")


## Called from animation when stroke becomes active
func _set_stroke_active() -> void:
	_stroke_active = true


## Called from animation when stroke becomes inactive
func _set_stroke_inactive() -> void:
	_stroke_active = false
