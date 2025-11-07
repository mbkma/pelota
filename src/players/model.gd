class_name Model
extends Node3D

enum States { IDLE, MOVE, STROKE }

var player: Player

@onready var points = $Points
@onready var serve_point = points.get_node("BallServePoint").position
@onready var toss_point = points.get_node("BallTossPoint").position
@onready var forehand_up_point = points.get_node("ForehandUpPoint").position
@onready var forehand_down_point = points.get_node("ForehandDownPoint").position
@onready var backhand_up_point = points.get_node("BackhandUpPoint").position
@onready var backhand_down_point = points.get_node("BackhandDownPoint").position
@onready var backhandslice_up_point = points.get_node("BackhandSliceUpPoint").position
@onready var backhandslice_down_point = points.get_node("BackhandSliceDownPoint").position

@onready var racket_forehand: Area3D = $RacketForehand
@onready var racket_backhand: Area3D = $RacketBackhand

var movement_animations := {
	"crossover_right": preload("res://src/players/anim_crossover_right.tres")
}

var stroke_animations := {"forehand": preload("res://src/players/forehand_anim.tres")}

var stroke_active := false

@export var animation_tree: AnimationTree
@onready var _playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")


func _ready() -> void:
	player = get_parent()
	animation_tree.active = true


func get_move_speed_factor():
	var current_time = _playback.get_current_play_position()
	var current_animation = _playback.get_current_node()
	var current_length := _playback.get_current_length()
	var w := 1.0
	if current_animation == "g_right":
		w = movement_animations["crossover_right"].sample(current_time / current_length)
		print("w", w)
		print("current_time", current_time)
		print("current_length", current_length)

	return w


func set_move_direction(direction: Vector3) -> void:
	# Transform world-space direction to player's local space for correct animation
	# This ensures the animation always plays in the correct direction regardless of player orientation
	var local_direction = player.global_transform.basis.inverse() * direction
	var dir := Vector2(local_direction.x, -local_direction.z)
	animation_tree["parameters/move/blend_position"] = dir
	#transition_to(States.MOVE)


func get_stroke_blend_position(stroke_id: int, stroke_pos: Vector3) -> Vector3:
	var point_down := Vector3.ZERO
	var point_up := Vector3.ZERO
	#match stroke_id:
	#Strokes.FOREHAND:
	#point_down = forehand_down_point
	#point_up = forehand_up_point
	#Strokes.BACKHAND:
	#point_down = backhand_down_point
	#point_up = backhand_up_point
	#Strokes.BACKHAND_SLICE:
	#point_down = backhandslice_up_point
	#point_up = backhandslice_down_point

	return (stroke_pos - point_down) / (point_up - point_down)


func play_stroke_animation(stroke: Stroke):
	print("stroke.step.time ", stroke.step.time)
	var animation_hit_time := 0.37
	if stroke.stroke_type == Stroke.StrokeType.FOREHAND:
		animation_hit_time = stroke_animations["forehand"].hit_zone[0]

	var t = max(0, stroke.step.time - animation_hit_time)
	if t > 0:
		await get_tree().create_timer(t).timeout

	transition_to(States.STROKE)
	set_stroke(stroke)


func set_stroke(stroke: Stroke) -> void:
	#var point := get_stroke_blend_position(stroke_id, stroke_pos)
	#animation_tree["parameters/stroke/forehand/blend_position"] = point.y
	#animation_tree["parameters/stroke/backhand/blend_position"] = point.y
	#animation_tree["parameters/stroke/backhand_slice/blend_position"] = point.y
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
			printerr("Stroke animation ", stroke.stroke_type, " not available!")
			return

	animation_tree["parameters/stroke/Transition/transition_request"] = animation_name


func transition_to(state_id: int) -> void:
	match state_id:
		States.IDLE:
			_playback.travel("move")
		States.MOVE:
			_playback.travel("move")
		States.STROKE:
			_playback.travel("stroke")
		#_:
		#_playback.travel("move")


# gets called from animation
func _set_stroke_active():
	stroke_active = true


func _set_stroke_inactive():
	stroke_active = false
