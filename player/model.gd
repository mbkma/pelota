## Player model with animations, skeleton points, and stroke handling
class_name Model
extends Node3D

## Emitted when stroke animation finishes
signal stroke_animation_finished

## Emitted when recovery animation finishes
signal recovery_animation_finished

## Emitted when the active ball enters the racket hit area
signal hit_area_ball_entered(ball: Ball)

## Reference to parent player
var player: Player

## Track last animation state for detecting transitions
var _last_state: String = ""

## Track if stroke animation finished signal was already emitted
var _stroke_finished_emitted: bool = false

@onready var points: Node3D = $Points
@onready var toss_point: Vector3 = points.get_node("BallTossPoint").position
@onready var forehand_up_point: Vector3 = points.get_node("ForehandUpPoint").position
@onready var forehand_point: Marker3D = $Points/ForehandPoint
@onready var forehand_down_point: Vector3 = points.get_node("ForehandDownPoint").position
@onready var backhand_up_point: Vector3 = points.get_node("BackhandUpPoint").position
@onready var backhand_down_point: Vector3 = points.get_node("BackhandDownPoint").position
@onready var backhand_point: Marker3D = $Points/BackhandPoint

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

@onready var hit_area_3d: Area3D = $"h/player_djokovic/game-rig/GeneralSkeleton/DEF-attachment_hand_R/racket/HitPoint/HitArea3D"


func _ready() -> void:
	var p = get_parent()
	if not p is Player:
		push_error("Model parent must be Player, got: " + str(p))
		set_process(false)
		return

	player = p
	animation_tree.active = true
	if hit_area_3d and not hit_area_3d.body_entered.is_connected(_on_hit_area_3d_body_entered):
		hit_area_3d.body_entered.connect(_on_hit_area_3d_body_entered)


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


func get_animation_hit_frame_time(stroke_type: Stroke.StrokeType) -> float:
	var anim_name: String = _stroke_animation_names.get(stroke_type, "")
	var animation: Animation = _animation_player.get_animation(anim_name)

	return animation.get_marker_time("hit")


func _on_hit_area_3d_body_entered(body: Node3D) -> void:
	if body is Ball:
		hit_area_ball_entered.emit(body)

## Called from animation timeline to spawn the ball (forwarded to player)
func _from_anim_spawn_ball() -> void:
	player.from_anim_spawn_ball()

## Called from animation timeline to hit the serve (forwarded to player)
func from_anim_hit_serve() -> void:
	player.from_anim_hit_serve()

func compute_stroke_blend_position(stroke: Stroke) -> float:
	if not stroke or not stroke.step:
		return 0.5

	var numerator: float = 0.0
	var denominator: float = 1.0

	match stroke.stroke_type:
		stroke.StrokeType.FOREHAND:
			numerator = stroke.step.point.y - forehand_down_point.y
			denominator = forehand_up_point.y - forehand_down_point.y
		stroke.StrokeType.BACKHAND:
			numerator = stroke.step.point.y - backhand_down_point.y
			denominator = backhand_up_point.y - backhand_down_point.y
		_:
			return 0.5

	if is_zero_approx(denominator):
		return 0.5

	var blend_position: float = numerator / denominator
	if not is_finite(blend_position):
		return 0.5

	return clampf(blend_position, 0.0, 1.0)


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
	var playback_speed = 1.0

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

	if stroke.stroke_type == stroke.StrokeType.FOREHAND or stroke.stroke_type == stroke.StrokeType.BACKHAND:
		var blend_position: float = compute_stroke_blend_position(stroke)
		animation_tree["parameters/stroke/" + animation_name + "/blend_position"] = blend_position
		Loggie.msg("blend position: ", blend_position).info()

	animation_tree["parameters/stroke/Transition/transition_request"] = animation_name
