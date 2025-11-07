## Main player entity that handles movement, strokes, and AI/human control
class_name Player
extends CharacterBody3D

## Emitted when player successfully hits the ball
signal ball_hit

## Emitted immediately after serve is executed
signal just_served

## Emitted when player reaches movement target point
signal target_point_reached

## Emitted when player is ready to serve
signal ready_to_serve

## Emitted when player is ready to receive
signal ready_to_receive

## Emitted when player challenges a call
signal challenged

## Emitted when ball is spawned for serve
signal ball_spawned(ball: Ball)

## Emitted when input method is changed
signal input_changed(timing: float)

@onready var ball_scene := preload("res://src/ball.tscn")
@onready var model: Model = $Model
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

var ai_input: String = "res://src/players/inputs/ai/ai_input.tscn"
var human_input: String = "res://src/players/inputs/keyboard_input.tscn"

enum InputType { KEYBOARD, CONTROLLER, AI }
@export var input: InputType
@export var input_node: InputMethod
@export var player_data: PlayerData
@export var stats: Dictionary = {}
@export var camera: Camera3D
@export var ball: Ball
@export var move_speed: float = 5.0
@export var team_index: int = 0
@export var ball_aim_marker: MeshInstance3D

## Flat stroke sound effects
@export var stroke_sounds_flat: Array[AudioStream] = [
	preload("res://assets/sounds/flat_stroke1.wav"),
	preload("res://assets/sounds/flat_stroke2.wav"),
	preload("res://assets/sounds/flat_stroke3.wav"),
]

## Slice stroke sound effects
@export var stroke_sounds_slice: Array[AudioStream] = [
	preload("res://assets/sounds/slice_stroke1.wav"),
	preload("res://assets/sounds/slice_stroke2.wav"),
	preload("res://assets/sounds/slice_stroke3.wav"),
]

## Currently queued stroke to execute
var queued_stroke: Stroke

## Current movement velocity
var _move_velocity: Vector3 = Vector3.ZERO

## Actual movement velocity after acceleration/friction
var _real_velocity: Vector3 = Vector3.ZERO

## Friction factor for deceleration (0-1, higher = slower deceleration)
var _friction: float = 1.0

## Acceleration factor for speed ramping (0-1, higher = faster acceleration)
var _acceleration: float = 0.1

## Movement path waypoints
var _path: Array[Vector3] = []

## Whether to use root motion for movement
var _root_motion: bool = false

const DISTANCE_THRESHOLD: float = 0.01


func _ready() -> void:
	stats = player_data.stats
	$Label3D.text = player_data.last_name
	model.racket_forehand.body_entered.connect(_on_RacketArea_body_entered)
	model.racket_backhand.body_entered.connect(_on_RacketArea_body_entered)


## Request the input handler to initiate a serve
func request_serve() -> void:
	input_node.request_serve()


## Setup player with given data and control method
func setup(data: PlayerData, ai_controlled: bool) -> void:
	player_data = data


## Setup player for training mode
func setup_training(training_data: Dictionary) -> void:
	pass


## Stop all player actions and clean up state
func stop() -> void:
	cancel_movement()
	cancel_stroke()
	ball = null


## Movement System
####################

## Apply movement in given direction
func apply_movement(direction: Vector3, delta: float) -> void:
	if _root_motion:
		_root_motion_movement(direction, delta)
		return

	direction = direction.normalized()
	model.set_move_direction(direction)

	_move_velocity.x = direction.x * move_speed
	_move_velocity.z = direction.z * move_speed

	# If there's input, accelerate to the input move_velocity
	if direction.length() > 0:
		_real_velocity = _real_velocity.lerp(_move_velocity, _acceleration)
	else:
		# If there's no input, slow down to (0, 0)
		_real_velocity = _real_velocity.lerp(Vector3.ZERO, _friction)

	_real_velocity *= model.get_move_speed_factor()

	velocity = _real_velocity
	move_and_slide()


## Apply movement using animation root motion
func _root_motion_movement(direction: Vector3, delta: float) -> void:
	direction = direction.normalized()

	var dir := Vector2(-direction.x, direction.z)
	model.animation_tree["parameters/move/blend_position"] = dir

	# Set animation conditions for root motion
	model.animation_tree.set("parameters/conditions/moving", direction != Vector3.ZERO)
	model.animation_tree.set("parameters/conditions/idle", direction == Vector3.ZERO)

	var current_rotation: Quaternion = transform.basis.get_rotation_quaternion()
	velocity = (
		(current_rotation.normalized() * model.animation_tree.get_root_motion_position()) / delta
	)
	move_and_slide()


## Compute movement direction from path
func compute_move_dir() -> Vector3:
	var move_direction: Vector3 = Vector3.ZERO
	if _path.size() > 0:
		assert(_path.size() == 1)
		move_direction = _get_move_direction()

	return move_direction


## Get movement direction toward next waypoint
func _get_move_direction() -> Vector3:
	var direction: Vector3 = Vector3.ZERO
	if _path.size() > 0:
		if position.distance_squared_to(_path[0]) < DISTANCE_THRESHOLD:
			_path.remove_at(0)
			target_point_reached.emit()
		else:
			direction = (_path[0] - position).normalized()
			direction.y = 0

	return direction


## Queue a movement to target position
func move_to(target: Vector3) -> void:
	cancel_movement()
	_path.append(target)


## Cancel all pending movement
func cancel_movement() -> void:
	_path = []


## Stroke System
##################

## Queue a stroke to execute (non-serve strokes)
func queue_stroke(stroke: Stroke) -> void:
	if not ball:
		push_error("Player has no ball to stroke!")
		return

	queued_stroke = stroke
	model.play_stroke_animation(stroke)


## Handle racket collision with ball
func _on_RacketArea_body_entered(body: Node3D) -> void:
	if not body is Ball or not queued_stroke:
		return

	_hit_ball(ball, queued_stroke)
	queued_stroke = null


## Execute ball hit with given stroke
func _hit_ball(hit_ball: Ball, stroke: Stroke) -> void:
	var stroke_velocity: Vector3 = GlobalPhysics.calculate_velocity(
		hit_ball.position,
		stroke.stroke_target,
		-sign(position.z) * stroke.stroke_power,
		stroke.stroke_spin
	)

	hit_ball.apply_stroke(stroke_velocity, stroke.stroke_spin)
	play_stroke_sound(stroke)
	ball_hit.emit()
	cancel_stroke()


## Cancel currently queued stroke
func cancel_stroke() -> void:
	queued_stroke = null
	model.transition_to(model.States.IDLE)


## Execute a serve with given stroke
func serve(stroke: Stroke) -> void:
	if ball:
		ball.queue_free()

	model.set_stroke(stroke)
	model.transition_to(model.States.STROKE)

	ball = ball_scene.instantiate()
	ball.initial_position = position + model.toss_point
	ball.initial_velocity = Vector3(0, 6, 0)
	get_parent().add_child(ball)
	ball_spawned.emit(ball)

	get_tree().call_group("Player", "set_active_ball", ball)
	await get_tree().create_timer(GameConstants.FAULT_DELAY).timeout

	_hit_ball(ball, stroke)
	just_served.emit()


## Other Functions
####################

## Notify player is ready to serve
func prepare_serve() -> void:
	ready_to_serve.emit()


## Challenge a call (emit challenge signal)
func challenge() -> void:
	challenged.emit()


## Get a random grunt sound from player data
func _get_grunt_sound() -> AudioStream:
	var grunts: Array[AudioStream] = player_data.sounds.grunt_flat
	if grunts and grunts.size() > 0:
		return grunts[randi() % grunts.size()]
	return null


## Play sound for given stroke
func play_stroke_sound(stroke: Stroke) -> void:
	var stream: AudioStream

	if randf() < player_data.sounds.grunt_frequency:
		stream = _get_grunt_sound()
	else:
		if stroke.stroke_type == stroke.StrokeType.BACKHAND_SLICE:
			if stroke_sounds_slice.size() > 0:
				stream = stroke_sounds_slice[randi() % stroke_sounds_slice.size()]
		else:
			if stroke_sounds_flat.size() > 0:
				stream = stroke_sounds_flat[randi() % stroke_sounds_flat.size()]

	if stream:
		audio_stream_player.stream = stream
		audio_stream_player.play()


## Set the active ball for this player
func set_active_ball(b: Ball) -> void:
	ball = b
