## Main player entity that handles movement, strokes, and AI/human control
class_name Player
extends CharacterBody3D

## Player state enum
enum PlayerState { IDLE, MOVING, PREPARING_STROKE, STROKING, RECOVERING, UNREACHABLE }

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
		Loggie.msg("Setting queued stroke to: ", value).debug()

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

## Timing system variables for animation synchronization
## Time when ball will arrive at predicted hit location (set by opponent hit prediction)
var _ball_prediction_time: float = 0.0

## Time required for player to travel from current position to hit location
var _travel_time: float = 0.0

## Time in animation when racket contacts ball (frame-specific, set from Model)
var _animation_hit_point_time: float = 0.0

## Calculated time when animation should start to sync with ball arrival
var _animation_start_time: float = 0.0

## Whether the player is currently doing a synchronized stroke (AI-driven)
var _is_synchronized_stroke: bool = false

## Whether the player cannot reach the ball in time
var _is_unreachable: bool = false

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
		PlayerState.UNREACHABLE:
			# Player cannot reach ball in time - still move in correct direction but with unreachable behavior
			_is_unreachable = true
			if _path.size() > 0:
				model.play_run((_path[0] - position).normalized())


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


## Timing System
#################
##
## ARCHITECTURE:
## The timing system synchronizes player movement and animations with predicted ball arrival.
## This is used for AI opponents that need to meet the ball at a specific location and time.
##
## ANIMATION MARKERS:
## Each stroke animation has a "hit" marker indicating when the racket contacts the ball.
## The Model script queries this marker at runtime from Animation resources.
##
## FLOW:
## 1. Opponent hits ball -> system predicts ball location and arrival time
## 2. queue_stroke() is called with ball_prediction_time and hit location
## 3. compute_synchronized_stroke_timing() calculates travel time and animation sync
## 4. Player moves to hit location
## 5. On arrival, _on_target_point_reached() delays animation until sync time
## 6. Animation plays such that hit-frame aligns with ball arrival

## Compute travel time from current position to target using movement speed and acceleration
##
## CALCULATION:
## - Measures straight-line distance to target
## - Divides by average movement speed (accounting for acceleration ramp-up)
## - Returns time in seconds needed to reach the target
func compute_travel_time(target_position: Vector3) -> float:
	var distance: float = position.distance_to(target_position)

	# Simplified travel time: distance / average_speed
	# Account for acceleration ramp-up: assume we reach max speed fairly quickly
	var average_speed: float = move_speed * 0.8  # Conservative estimate during acceleration

	if average_speed <= 0:
		return INF

	return distance / average_speed

## Compute animation start time to sync hit frame with ball arrival
##
## FORMULA:
##   animation_start_time = ball_prediction_time - animation_hit_point_time
##
## EXPLANATION:
## - ball_prediction_time: when the ball will arrive at the hit location (absolute time)
## - animation_hit_point_time: when in the animation the racket contacts the ball (relative to anim start)
## - animation_start_time: when to START the animation so hit-frame lands at ball arrival
##
## EXAMPLE:
## - Ball arrives at t=5.0s
## - Hit frame is at 0.45s into animation
## - Start animation at t=4.55s so racket meets ball at t=5.0s
func compute_animation_start_time(ball_arrival_time: float, animation_hit_frame_time: float) -> float:
	return ball_arrival_time - animation_hit_frame_time

## Compute and validate synchronized stroke timing
## Returns true if player can reach and sync properly, false if unreachable
##
## VALIDATION LOGIC:
## - If travel_time > ball_prediction_time: player cannot reach in time -> UNREACHABLE
## - If travel_time <= ball_prediction_time: player can reach and sync -> SUCCESS
##
## SETS:
## - _animation_hit_point_time: when in animation the racket contacts the ball
## - _travel_time: how long it takes to reach the hit location
## - _animation_start_time: when animation should start for perfect sync
## - _ball_prediction_time: predicted ball arrival time (stored for reference)
func compute_synchronized_stroke_timing(
	hit_location: Vector3,
	ball_prediction_time: float,
	stroke: Stroke
) -> bool:
	# Get animation hit frame time from Model
	_animation_hit_point_time = model.get_animation_hit_frame_time(stroke.stroke_type)

	# Compute travel time from current position to hit location
	_travel_time = compute_travel_time(hit_location)

	# Compute when animation should start
	_animation_start_time = compute_animation_start_time(ball_prediction_time, _animation_hit_point_time)

	_ball_prediction_time = ball_prediction_time

	# Check if player can reach the ball
	if _travel_time > ball_prediction_time:
		_is_unreachable = true
		Loggie.msg(
			"UNREACHABLE: travel_time(%.2f) > prediction_time(%.2f)" % [_travel_time, ball_prediction_time]
		).warn()
		return false

	_is_unreachable = false
	_is_synchronized_stroke = true

	Loggie.msg(
		"Synchronized stroke timing: travel=%.2f, anim_hit=%.2f, prediction=%.2f, start_time=%.2f" %
		[_travel_time, _animation_hit_point_time, ball_prediction_time, _animation_start_time]
	).info()

	return true

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
		# For synchronized strokes, wait until correct animation start time
		if _is_synchronized_stroke:
			# Calculate remaining wait time before animation should start
			var current_time: float = Time.get_ticks_msec() / 1000.0
			var wait_time: float = _animation_start_time - (current_time - 0)  # Adjust based on game timing

			if wait_time > 0:
				# Delay animation start until sync point
				Loggie.msg("Waiting %.2f seconds before stroke animation start" % wait_time).info()
				await get_tree().create_timer(wait_time).timeout

		_set_state(PlayerState.STROKING)
		model.play_stroke(queued_stroke)


## Stroke System
##################


## Queue a stroke to execute (non-serve strokes)
## For AI: Uses synchronized timing if ball_prediction_time is set
## For human: Executes immediately when player is close enough
func queue_stroke(stroke: Stroke, ball_prediction_time: float = 0.0) -> void:
	if not ball:
		push_error("Player has no ball to stroke!")
		return

	queued_stroke = stroke

	# AI/Synchronized stroke path
	if ball_prediction_time > 0 and _path.size() > 0:
		var hit_location: Vector3 = _path[0]
		if not compute_synchronized_stroke_timing(hit_location, ball_prediction_time, stroke):
			# Cannot reach - switch to UNREACHABLE state
			_set_state(PlayerState.UNREACHABLE)
			return

	# Otherwise proceed with normal movement -> stroke execution on arrival


## Queue and execute a reactive stroke for human input (immediate execution)
##
## HUMAN CONTROLLER BEHAVIOR:
## When a human player presses a hit button, this method starts the stroke animation immediately
## without synchronization calculations. The hit frame from the animation will determine timing.
##
## EARLY VS LATE:
## - Early: Human hits button before ball arrives (animation finishes before ball contact)
## - Late: Human hits button when ball is already close (animation may miss the ball)
##
## The racket collision system handles actual ball contact - if the ball is in range when
## the animation reaches the hit frame, collision detection will execute the hit.
func queue_reactive_stroke(stroke: Stroke) -> void:
	if not ball:
		push_error("Player has no ball to stroke!")
		return

	queued_stroke = stroke
	_is_synchronized_stroke = false

	# Determine current ball-player distance
	var ball_distance: float = position.distance_to(ball.position)

	# Get animation hit frame time
	_animation_hit_point_time = model.get_animation_hit_frame_time(stroke.stroke_type)

	# For human reactive strokes, start animation immediately
	# The hit will connect when the racket animation reaches the hit frame
	_set_state(PlayerState.STROKING)
	model.play_stroke(stroke)

	Loggie.msg(
		"Reactive stroke queued: distance_to_ball=%.2f, anim_hit_frame=%.2f" %
		[ball_distance, _animation_hit_point_time]
	).info()


## Handle racket collision with ball
func _on_RacketArea_body_entered(body: Node3D) -> void:
	if not body is Ball:
		return
	if not queued_stroke:
		Loggie.msg("Ball entered but no queued stroke").info()
		return
	Loggie.msg(player_data.last_name, ": ball entered").debug()
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
		Loggie.msg("SERVING").info()
	
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
