## Main player entity that handles movement, strokes, and AI/human control
class_name Player
extends CharacterBody3D

## Player state enum
enum PlayerState { IDLE, MOVING, PREPARING_STROKE, STROKING, RECOVERING }

## Emitted when player successfully hits the ball
signal ball_hit

## Emitted immediately after serve is executed
signal just_served

## Emitted when player reaches movement target point
signal target_point_reached

## Emitted when player is ready to serve
signal ready_to_serve

## Emitted when player challenges a call
signal challenged

## Emitted when ball is spawned for serve
signal ball_spawned(ball: Ball)

@onready var model: Model = $Model
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var third_person_camera: Camera3D = $ThirdPersonCamera


@export var controller_scene: PackedScene
@export var player_data: PlayerData
@export var stats: Dictionary = {}
@export var camera: Camera3D
@export var ball: Ball
@export var move_speed: float = 5.0
@export var team_index: int = 0
@export var ball_aim_marker: Node3D
@export var opponent: Player  # Reference to opponent player

## Flat stroke sound effects
@export var stroke_sounds_flat: Array[AudioStream]

## Slice stroke sound effects
@export var stroke_sounds_slice: Array[AudioStream]

## Currently queued stroke to execute
var queued_stroke: Stroke:
	get:
		return queued_stroke
	set(value):
		queued_stroke = value
		Loggie.msg("[Player] Setting queued stroke to: ", value).debug()

## Current player state
var _current_state: PlayerState = PlayerState.IDLE

var controller: Controller

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


## Angle bisector visualization data for debug drawing
var bisector_service_line_left: Vector3 = Vector3.ZERO
var bisector_service_line_right: Vector3 = Vector3.ZERO
var bisector_direction: Vector3 = Vector3.ZERO
var opponent_hit_position: Vector3 = Vector3.ZERO

const DISTANCE_THRESHOLD: float = 0.01


func _ready() -> void:
	stats = player_data.stats
	$Label3D.text = player_data.last_name
	model.racket_forehand.body_entered.connect(_on_RacketArea_body_entered)
	model.racket_backhand.body_entered.connect(_on_RacketArea_body_entered)
	target_point_reached.connect(_on_target_point_reached)
	model.stroke_animation_finished.connect(_on_stroke_animation_finished)
	controller = controller_scene.instantiate()
	add_child(controller)
	_set_state(PlayerState.IDLE)


## Set player state and handle state transitions
func _set_state(new_state: PlayerState) -> void:
	if _current_state == new_state:
		return

	_current_state = new_state

	match _current_state:
		PlayerState.IDLE:
			model.play_idle()
		PlayerState.MOVING:
			pass  # Animation handled by apply_movement
		PlayerState.PREPARING_STROKE:
			pass  # Animation handled when stroke is queued
		PlayerState.STROKING:
			pass  # Animation handled by play_stroke_animation
		PlayerState.RECOVERING:
			model.play_recovery()


## Process stroke decisions from controller each frame
func _process(_delta: float) -> void:
	if not controller:
		return

	# Update controller state (uniform interface for all controllers)
	controller.update()

	# Update UI based on controller state
	_update_controller_ui()

	# Check if controller has a stroke decision
	var stroke_decision: Stroke = controller.get_stroke()
	if stroke_decision:
		# Execute the stroke decision
		if stroke_decision.stroke_type == Stroke.StrokeType.SERVE:
			serve(stroke_decision)
		else:
			queue_stroke(stroke_decision)

		# Clear UI after stroke is queued
		if ball_aim_marker:
			ball_aim_marker.visible = false


## Process movement from controller each physics frame
func _physics_process(delta: float) -> void:
	if not controller:
		return

	# Get movement direction from controller and execute it
	var move_direction: Vector3 = controller.get_move_direction()
	apply_movement(move_direction, delta)

## Request the input handler to initiate a serve
func request_serve() -> void:
	controller.request_serve()

## Setup player with given data and control method
func setup(data: PlayerData, _ai_controlled: bool) -> void:
	player_data = data


## Setup player for training mode
func setup_training(_training_data: Dictionary) -> void:
	pass


## Stop all player actions and clean up state
func stop() -> void:
	cancel_movement()
	cancel_stroke()
	ball = null


## Movement System
####################


## Apply movement in given direction
func apply_movement(direction: Vector3, _delta: float) -> void:
	# Separate animation direction from movement direction
	var animation_direction: Vector3 = direction
	direction = direction.normalized()

	_move_velocity.x = direction.x * move_speed
	_move_velocity.z = direction.z * move_speed

	# If there's input, accelerate to the input move_velocity
	if direction.length() > 0:
		_real_velocity = _real_velocity.lerp(_move_velocity, _acceleration)
	else:
		# If there's no input, slow down to (0, 0)
		_real_velocity = _real_velocity.lerp(Vector3.ZERO, _friction)

	#_real_velocity *= model.get_move_speed_factor()

	velocity = _real_velocity
	move_and_slide()

	# Update animation state based on movement (only if not stroking or recovering)
	if _current_state != PlayerState.STROKING and _current_state != PlayerState.RECOVERING:
		if animation_direction.length() > 0:
			_set_state(PlayerState.MOVING)
			model.play_run(animation_direction)
		else:
			_set_state(PlayerState.IDLE)



## Apply movement using animation root motion

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


## Move to defensive position after stroke animation finishes
func move_to_defensive_position(target_position: Vector3) -> void:
	await model.stroke_animation_finished
	Loggie.msg("Player now moving to defensive pos ", target_position).info()
	move_to(target_position)


## Called when player reaches movement target point
func _on_target_point_reached() -> void:
	# Play stroke animation if one is waiting for position
	if queued_stroke:
		_set_state(PlayerState.STROKING)
		model.play_stroke(queued_stroke)


## Stroke System
##################


## Queue a stroke to execute (non-serve strokes)
## Animation will be played when the player reaches the correct position
func queue_stroke(stroke: Stroke) -> void:
	if not ball:
		push_error("Player has no ball to stroke!")
		return

	queued_stroke = stroke


## Handle racket collision with ball
func _on_RacketArea_body_entered(body: Node3D) -> void:
	if not body is Ball:
		return
	if not queued_stroke:
		Loggie.msg("Ball entered but no queued stroke").info()
		return
	Loggie.msg("[Player] ", player_data.last_name, ": ball entered").debug()
	_hit_ball(queued_stroke)


## Execute ball hit with given stroke
func _hit_ball(stroke: Stroke) -> void:
	if not stroke:
		Loggie.msg("_hit_ball: No queued stroke").info()
		return

	var stroke_velocity: Vector3 = ball.calculate_velocity(
		ball.position,
		stroke.stroke_target,
		-sign(position.z) * stroke.stroke_power,
		stroke.stroke_spin
	)

	ball.apply_stroke(stroke_velocity, stroke.stroke_spin)
	play_stroke_sound(stroke)
	ball_hit.emit()
	cancel_stroke()


## Cancel currently queued stroke
func cancel_stroke() -> void:
	queued_stroke = null
	_set_state(PlayerState.IDLE)


## Execute a serve with given stroke
func serve(stroke: Stroke) -> void:
	queued_stroke = stroke
	_set_state(PlayerState.STROKING)
	model.play_stroke(stroke)
	# Animation callbacks will handle spawning ball and hitting it


## Called by serve animation to hit the ball
func from_anim_hit_serve() -> void:
		_hit_ball(queued_stroke)
		just_served.emit()
		Loggie.msg("[Player] SERVING").debug()
	
## Called by serve animation to spawn the ball at toss point
func from_anim_spawn_ball() -> void:
	ball = GlobalScenes.BALL_SCENE.instantiate()
	ball.initial_position = position + model.toss_point
	ball.initial_velocity = Vector3(0, 5, 0)
	get_parent().add_child(ball)
	ball_spawned.emit(ball)
	get_tree().call_group("Player", "set_active_ball", ball)
	Loggie.msg("from_anim_spawn_ball: stroke: ", queued_stroke, ", ball: ", ball).info()

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
	var grunts: Array = player_data.sounds.grunt_flat
	if grunts and grunts.size() > 0:
		return grunts[randi() % grunts.size()] as AudioStream
	return null


## Play sound for given stroke
func play_stroke_sound(stroke: Stroke) -> void:
	var stream: AudioStream

	if (stroke.stroke_type == stroke.StrokeType.BACKHAND_SLICE or
		stroke.stroke_type == stroke.StrokeType.BACKHAND_DROP_SHOT):
		stream = stroke_sounds_slice[randi() % stroke_sounds_slice.size()]
	else:
		if randf() < player_data.sounds.grunt_frequency:
			stream = _get_grunt_sound()
		else:
			stream = stroke_sounds_flat[randi() % stroke_sounds_flat.size()]

	if stream:
		audio_stream_player.stream = stream
		audio_stream_player.play()


## Set the active ball for this player
func set_active_ball(b: Ball) -> void:
	ball = b


## Update UI based on controller state (uniform interface for all controllers)
func _update_controller_ui() -> void:
	if not ball_aim_marker or not controller:
		return

	# Check if controller wants to show aim marker
	if controller.should_show_aim_marker():
		var aim_position: Variant = controller.get_aim_marker_position()
		if aim_position != null:
			ball_aim_marker.global_position = aim_position
			ball_aim_marker.scale = controller.get_aim_marker_scale()
			ball_aim_marker.visible = true
	else:
		# Controller doesn't need aim marker visible
		pass  # Don't hide here, only hide after stroke execution


## Called when stroke animation finishes
func _on_stroke_animation_finished() -> void:
	if _current_state == PlayerState.STROKING:
		_set_state(PlayerState.RECOVERING)
