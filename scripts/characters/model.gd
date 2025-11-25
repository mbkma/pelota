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

## Movement animation resources
@export var _movement_animations: Dictionary[String, Resource]

## Stroke animation resources
@export var _stroke_animations: Dictionary[String, StrokeAnimation]

## Whether a stroke is currently active
var _stroke_active: bool = false

@export var animation_tree: AnimationTree
@onready var _playback: AnimationNodeStateMachinePlayback = (
	animation_tree.get("parameters/playback")
)


func _ready() -> void:
	var p = get_parent()
	if p is Player:
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



## Play stroke animation with proper timing
func play_stroke_animation(stroke: Stroke) -> void:
	var animation_hit_time: float = GameConstants.ANIMATION_HIT_TIME
	if stroke.stroke_type == Stroke.StrokeType.FOREHAND:
		animation_hit_time = _stroke_animations["forehand"].hit_time
	elif stroke.stroke_type == Stroke.StrokeType.BACKHAND:
		animation_hit_time = _stroke_animations["backhand"].hit_time
	elif stroke.stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		animation_hit_time = _stroke_animations["backhand_slice"].hit_time
	
	#var t: float = max(0, stroke.step.time - animation_hit_time)
	#if t > 0:
		#await get_tree().create_timer(t).timeout

	var playback_speed = compute_animation_speed(31.0 / 30.0, stroke.step.time)
	playback_speed = clamp(playback_speed, 0.5, 3)
	animation_tree.set("parameters/stroke/TimeScale/scale", playback_speed)
	print("playback_speed!!! ", playback_speed, " time ",  stroke.step.time)
	set_stroke(stroke)
	transition_to(States.STROKE)

func compute_animation_speed(anim_time_to_contact: float, real_time_to_contact: float) -> float:
	# prevent division by zero
	if real_time_to_contact <= 0.01:
		return 1.0
	print("compute_animation_speed", anim_time_to_contact / real_time_to_contact)
	return anim_time_to_contact / real_time_to_contact


## Set stroke animation type based on stroke
func set_stroke(stroke: Stroke) -> void:
	var animation_name: String
	match stroke.stroke_type:
		stroke.StrokeType.FOREHAND:
			animation_name = "forehand"
			#animation_tree["parameters/stroke/forehand/blend_position"] = compute_stroke_blend_position(stroke)
			#print("## forehand", animation_tree["parameters/stroke/forehand/blend_position"])

		stroke.StrokeType.SERVE:
			animation_name = "serve"
		stroke.StrokeType.BACKHAND:
			animation_name = "backhand"
			animation_tree["parameters/stroke/backhand/blend_position"] = compute_stroke_blend_position(stroke)
			print("## backhand", animation_tree["parameters/stroke/backhand/blend_position"])
		stroke.StrokeType.BACKHAND_SLICE:
			animation_name = "backhand_slice"
		stroke.StrokeType.BACKHAND_DROP_SHOT:
			animation_name = "backhand_slice"
		_:
			push_warning("Stroke animation ", stroke.stroke_type, " not available!")

	animation_tree["parameters/stroke/Transition/transition_request"] = animation_name

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
