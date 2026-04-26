## Main player entity that handles movement, strokes, and AI/human control
class_name Player
extends CharacterBody3D

const PLAYER_STATE_MACHINE_SCRIPT: Script = preload("res://scripts/gameplay/players/state_machine.gd")
const MOVEMENT_SERVICE_SCRIPT: Script = preload("res://scripts/gameplay/players/services/movement_service.gd")
const TRAJECTORY_SERVICE_SCRIPT: Script = preload("res://scripts/gameplay/players/services/trajectory_service.gd")
const STROKE_SERVICE_SCRIPT: Script = preload("res://scripts/gameplay/players/services/stroke_service.gd")
const MATCH_LIFECYCLE_BUS_SCRIPT: Script = preload("res://scripts/gameplay/match/lifecycle_bus.gd")
const BALL_FACTORY_SCRIPT: Script = preload("res://scripts/gameplay/ball/ball_factory.gd")

enum PlayerState {
	IDLE,
	MOVING,
	PREPARING_STROKE,
	STROKING,
	RECOVERING,
	UNREACHABLE,
}

## Emitted when player successfully hits the ball
signal ball_hit

## Emitted when player reaches movement target point
signal target_point_reached

## Emitted when player is ready to serve
signal ready_to_serve

## Emitted when player challenges a call
signal challenged

## Emitted when ball is spawned for serve
signal ball_spawned(ball: Ball)

## Emitted when match lifecycle phase changes
signal lifecycle_phase_changed(previous_phase: int, current_phase: int)

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
@export var serve_ball_scene: PackedScene

## Flat stroke sound effects
@export var stroke_sounds_flat: Array[AudioStream]
@onready var label_3d: Label3D = $Label3D

## Slice stroke sound effects
@export var stroke_sounds_slice: Array[AudioStream]

## Movement tuning
@export var friction: float = 1.0
@export var acceleration: float = 0.1

var _state_machine: Node
var _movement_service: RefCounted = MOVEMENT_SERVICE_SCRIPT.new()
var _trajectory_service: RefCounted = TRAJECTORY_SERVICE_SCRIPT.new()
var _stroke_service: RefCounted = STROKE_SERVICE_SCRIPT.new()
var _lifecycle_bus: MatchLifecycleBus
var _ball_factory: BallFactory

var queued_stroke: Stroke:
	get:
		return _stroke_service.get_queued_stroke()
	set(value):
		_stroke_service.set_queued_stroke(value)
		Loggie.msg(player_data.last_name + ": ", "Setting queued stroke to: ", value).debug()

var controller: Controller

## Time in animation when racket contacts ball (frame-specific, set from Model)
var _animation_hit_point_time: float = 0.0

## Whether the player cannot reach the ball in time
## Angle bisector visualization data for debug drawing
var bisector_service_line_left: Vector3 = Vector3.ZERO
var bisector_service_line_right: Vector3 = Vector3.ZERO
var bisector_direction: Vector3 = Vector3.ZERO
var opponent_hit_position: Vector3 = Vector3.ZERO


func _can_update_movement_animation() -> bool:
	return not _state_machine.blocks_movement_animation()


func _ready() -> void:
	stats = player_data.stats
	label_3d.text = player_data.last_name
	_state_machine = PLAYER_STATE_MACHINE_SCRIPT.new()
	_state_machine.name = "PlayerStateMachine"
	add_child(_state_machine)
	_state_machine.state_entered.connect(_on_state_entered)

	_lifecycle_bus = MATCH_LIFECYCLE_BUS_SCRIPT.new()
	_lifecycle_bus.name = "MatchLifecycleBus"
	add_child(_lifecycle_bus)
	_lifecycle_bus.phase_changed.connect(_on_lifecycle_phase_changed)

	_ball_factory = BALL_FACTORY_SCRIPT.new(serve_ball_scene)

	target_point_reached.connect(_on_target_point_reached)
	model.stroke_animation_finished.connect(_on_stroke_animation_finished)
	controller = controller_scene.instantiate()
	controller.bind(self)
	add_child(controller)
	_set_state(PLAYER_STATE_MACHINE_SCRIPT.State.IDLE)
	_lifecycle_bus.set_phase(MATCH_LIFECYCLE_BUS_SCRIPT.Phase.IDLE)


## Set player state through dedicated state machine
func _set_state(new_state: int) -> void:
	_state_machine.transition_to(new_state)

## Process stroke decisions from controller each frame
func _process(delta: float) -> void:
	if not controller:
		return

	# Update controller state (uniform interface for all controllers)
	controller.update(delta)

	# Update UI based on controller state
	_update_controller_ui()

	_consume_controller_stroke_decision()

	if queued_stroke and queued_stroke.stroke_type != queued_stroke.StrokeType.SERVE and ball_is_in_reachable_window():
		_hit_ball(queued_stroke)


func _consume_controller_stroke_decision() -> void:
	_stroke_service.consume_controller_stroke_decision(
		controller,
		serve,
		queue_stroke
	)


## Process movement from controller each physics frame
func _physics_process(delta: float) -> void:
	if not controller:
		return

	# Get movement direction from controller and execute it
	var move_direction: Vector3 = controller.get_move_direction()
	apply_movement(move_direction, delta)

## Request the input handler to initiate a serve
func request_serve() -> void:
	_lifecycle_bus.begin_serve_setup(self)
	controller.request_serve()

## Setup player with given data and control method
func setup(data: PlayerData, _ai_controlled: bool) -> void:
	player_data = data


## Stop all player actions and clean up state
func stop() -> void:
	cancel_movement()
	cancel_stroke()
	ball = null
	_lifecycle_bus.end_point(self)



## Movement System
####################


## Apply movement in given direction
func apply_movement(direction: Vector3, _delta: float) -> void:
	var animation_direction: Vector3 = _movement_service.apply_movement(
		self,
		direction,
		move_speed,
		acceleration,
		friction
	)

	# Update animation state based on movement (only if not stroking or recovering)
	if _can_update_movement_animation():
		if animation_direction.length() > 0:
			_set_state(PLAYER_STATE_MACHINE_SCRIPT.State.MOVING)
			model.play_run(animation_direction)
		else:
			_set_state(PLAYER_STATE_MACHINE_SCRIPT.State.IDLE)



## Apply movement using animation root motion

## Compute movement direction from path
func compute_move_dir() -> Vector3:
	if _movement_service.consume_target_reached_if_needed(position):
		target_point_reached.emit()

	return _movement_service.compute_move_dir(position)


## Queue a movement to target position
func request_move_to(target: Vector3) -> void:
	_movement_service.request_move_to(target)


## Cancel all pending movement
func cancel_movement() -> void:
	_movement_service.cancel_movement()


## Move to defensive position after stroke animation finishes
func move_to_defensive_position(target_position: Vector3) -> void:
	await model.stroke_animation_finished
	Loggie.msg(player_data.last_name + ": ", "Player now moving to defensive pos ", target_position).info()
	request_move_to(target_position)


## Called when player reaches movement target point
func _on_target_point_reached() -> void:
	# Play stroke animation if one is waiting for position
	if queued_stroke:
		var stroke = queued_stroke  # Store locally before await to prevent race condition
		_animation_hit_point_time = model.get_animation_hit_frame_time(stroke.stroke_type)
		var closest_step: TrajectoryStep = _trajectory_service.get_closest_step(controller, self)
		if not closest_step:
			push_warning("Player._on_target_point_reached: closest trajectory step unavailable")
			return
		var timing = closest_step.time - _animation_hit_point_time
		if timing > 0:
			await get_tree().create_timer(timing).timeout
			closest_step = _trajectory_service.get_closest_step(controller, self)
			if not closest_step:
				push_warning("Player._on_target_point_reached: trajectory changed before stroke")
				return
		_set_state(PLAYER_STATE_MACHINE_SCRIPT.State.STROKING)
		model.play_stroke(stroke)

## Stroke System
##################


func queue_stroke(stroke: Stroke) -> void:
	if not ball:
		push_error("Player has no ball to hit!")
		return

	queued_stroke = stroke

	# Determine current ball-player distance
	var ball_distance: float = position.distance_to(ball.position)

	# Get animation hit frame time
	_animation_hit_point_time = model.get_animation_hit_frame_time(stroke.stroke_type)

	Loggie.msg(player_data.last_name + ": ", 
		"Stroke queued: distance_to_ball=%.2f, anim_hit_frame=%.2f" %
		[ball_distance, _animation_hit_point_time]
	).info()


func ball_is_in_reachable_window() -> bool:
	return _trajectory_service.is_ball_in_reachable_window(ball, global_position, 3.0)


## Execute ball hit with given stroke
func _hit_ball(stroke: Stroke) -> void:
	if not stroke:
		Loggie.msg(player_data.last_name + ": ", "_hit_ball: No queued stroke").info()
		return

	var stroke_velocity: Vector3 = ball.calculate_velocity(
		ball.position,
		stroke.stroke_target,
		-sign(position.z) * stroke.stroke_power,
		stroke.stroke_spin
	)

	ball.apply_stroke(stroke_velocity, stroke.stroke_spin)
	play_stroke_sound(stroke)
	label_3d.text = player_data.last_name + "\n" + str(stroke.stroke_power)
	ball_hit.emit()
	cancel_stroke()


## Cancel currently queued stroke
func cancel_stroke() -> void:
	queued_stroke = null
	_stroke_service.clear()
	_set_state(PLAYER_STATE_MACHINE_SCRIPT.State.IDLE)


## Execute a serve with given stroke
func serve(stroke: Stroke) -> void:
	queued_stroke = stroke
	_set_state(PLAYER_STATE_MACHINE_SCRIPT.State.STROKING)
	_lifecycle_bus.start_serving(self, stroke)
	model.play_stroke(stroke)
	# Animation callbacks will handle spawning ball and hitting it


## Called by serve animation to hit the ball
func from_anim_hit_serve() -> void:
	Loggie.msg(player_data.last_name + ": ", "SERVING").info()
	_hit_ball(queued_stroke)
	_lifecycle_bus.complete_serve(self)
	
## Called by serve animation to spawn the ball at toss point
func from_anim_spawn_ball() -> void:
	ball = _ball_factory.create_ball(position + model.toss_point, Vector3(0, 5, 0))
	if not ball:
		return
	get_parent().add_child(ball)
	set_active_ball(ball)
	if opponent:
		opponent.set_active_ball(ball)
	ball_spawned.emit(ball)
	Loggie.msg(player_data.last_name + ": ", "from_anim_spawn_ball: stroke: ", queued_stroke, ", ball: ", ball).info()

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
	if controller:
		controller.ball_changed(b)


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
		ball_aim_marker.visible = false


## Called when stroke animation finishes
func _on_stroke_animation_finished() -> void:
	if _state_machine.get_state() == PLAYER_STATE_MACHINE_SCRIPT.State.STROKING:
		_set_state(PLAYER_STATE_MACHINE_SCRIPT.State.RECOVERING)


func _on_state_entered(new_state: int) -> void:
	match new_state:
		PLAYER_STATE_MACHINE_SCRIPT.State.IDLE:
			model.play_idle()
		PLAYER_STATE_MACHINE_SCRIPT.State.MOVING:
			pass
		PLAYER_STATE_MACHINE_SCRIPT.State.PREPARING_STROKE:
			pass
		PLAYER_STATE_MACHINE_SCRIPT.State.STROKING:
			pass
		PLAYER_STATE_MACHINE_SCRIPT.State.RECOVERING:
			model.play_recovery()
		PLAYER_STATE_MACHINE_SCRIPT.State.UNREACHABLE:
			var next_target: Variant = _movement_service.peek_next_target()
			if next_target != null:
				model.play_run((next_target - position).normalized())


func _on_lifecycle_phase_changed(previous_phase: int, current_phase: int) -> void:
	lifecycle_phase_changed.emit(previous_phase, current_phase)
	if controller:
		controller.on_lifecycle_phase_changed(previous_phase, current_phase)


func get_lifecycle_bus() -> MatchLifecycleBus:
	return _lifecycle_bus


func get_current_state() -> int:
	if _state_machine:
		return _state_machine.get_state()
	return PLAYER_STATE_MACHINE_SCRIPT.State.IDLE


func get_movement_path() -> Array[Vector3]:
	var next_target: Variant = _movement_service.peek_next_target()
	if next_target == null:
		return []
	return [next_target]
