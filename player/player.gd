## Main player entity that handles movement, strokes, and AI/human control
class_name Player
extends CharacterBody3D

const DISTANCE_THRESHOLD: float = 0.01

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

## Emitted when active ball reference changes
signal active_ball_changed(ball: Ball)

## Emitted when match lifecycle phase changes
signal lifecycle_phase_changed(previous_phase: int, current_phase: int)

@onready var model: Model = $Model
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var third_person_camera: Camera3D = $ThirdPersonCamera
@onready var _state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var _lifecycle_bus: MatchLifecycleBus = $MatchLifecycleBus


## Controller scene instantiated to drive movement/stroke decisions.
@export var controller_scene: PackedScene
## Optional per-player AI strategy override applied to AiController instances.
@export var ai_point_strategy: PointStrategy
## Static player identity/config data (name, handedness, sounds, stats).
@export var player_data: PlayerData
## Runtime stats dictionary copied from player_data for quick access.
@export var stats: Dictionary = {}
## Camera assigned to this player (used by controlling systems/UI).
@export var camera: Camera3D
## Current active ball this player tracks and can hit.
@export var ball: Ball
## Base horizontal movement speed in meters per second.
@export var move_speed: float = 6.0
## Team slot index used to group players in doubles/splitscreen contexts.
@export var team_index: int = 0
## World-space marker used to visualize shot aim target.
@export var ball_aim_marker: Node3D
## Opposing player reference for serve/rally synchronization.
@export var opponent: Player
## Ball scene used to spawn a toss ball when serving.
@export var serve_ball_scene: PackedScene
## Allowed timing error window around ideal contact time.
@export var hit_timing_window_seconds: float = 0.1
## Maximum distance from racket contact point that still counts as a hit.
@export var hit_range_tolerance_meters: float = 1.3
## If enabled, snap ball to racket contact point on animation hit frame.
@export var snap_ball_to_contact_point_on_anim_hit: bool = true
## Max snap distance allowed when contact-point snapping is enabled.
@export var snap_max_distance_meters: float = 1.8

## Flat stroke sound effect pool (non-slice hits/grunts fallback).
@export var stroke_sounds_flat: Array[AudioStream]
@onready var label_3d: Label3D = $Label3D

## Slice stroke sound effect pool used for slice/drop-shot variants.
@export var stroke_sounds_slice: Array[AudioStream]

## Interpolation factor for decelerating when no input is present.
@export var friction: float = 1.0
## Interpolation factor for accelerating toward target movement velocity.
@export var acceleration: float = 0.6

var _ball_factory: BallFactory
var _path: Array[Vector3] = []
var _move_velocity: Vector3 = Vector3.ZERO
var _real_velocity: Vector3 = Vector3.ZERO
var _queued_stroke: Stroke = null
var _last_consumed_decision: Stroke = null

var queued_stroke: Stroke:
	get:
		return _queued_stroke
	set(value):
		_queued_stroke = value
		Loggie.msg(player_data.last_name + ": ", "Setting queued stroke to: ", value).debug()

var controller: Controller

## Time in animation when racket contacts ball (frame-specific, set from Model)
var _animation_hit_point_time: float = 0.0
var _last_replay_visual_state: int = -1
var _is_replay_mode: bool = false

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
	
	# Set logger name for debug logging
	set_meta("logger_name", player_data.last_name)
	
	_state_machine.state_entered.connect(_on_state_entered)
	_lifecycle_bus.phase_changed.connect(_on_lifecycle_phase_changed)

	_ball_factory = BallFactory.new(serve_ball_scene)

	target_point_reached.connect(_on_target_point_reached)
	model.stroke_animation_finished.connect(_on_stroke_animation_finished)
	controller = controller_scene.instantiate()
	if controller is AiController and ai_point_strategy:
		(controller as AiController).point_strategy = ai_point_strategy
	controller.bind(self)
	add_child(controller)
	_set_state(PlayerStateMachine.State.IDLE)
	_lifecycle_bus.set_phase(MatchLifecycleBus.Phase.IDLE)


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


func _consume_controller_stroke_decision() -> void:
	if not controller:
		return

	_sync_ball_from_match_manager()

	var stroke_decision: Stroke = controller.get_stroke()
	if not stroke_decision:
		return

	if _last_consumed_decision == stroke_decision:
		return

	var decision_consumed: bool = false

	if stroke_decision.stroke_type == Stroke.StrokeType.SERVE:
		serve(stroke_decision)
		decision_consumed = true
	else:
		decision_consumed = queue_stroke(stroke_decision)

	if decision_consumed:
		_last_consumed_decision = stroke_decision


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
	set_active_ball(null)
	_lifecycle_bus.end_point(self)



## Movement System
####################


## Apply movement in given direction
func apply_movement(direction: Vector3, _delta: float) -> void:
	var animation_direction: Vector3 = direction
	direction = direction.normalized()

	_move_velocity.x = direction.x * move_speed
	_move_velocity.z = direction.z * move_speed

	if direction.length() > 0:
		_real_velocity = _real_velocity.lerp(_move_velocity, acceleration)
	else:
		_real_velocity = _real_velocity.lerp(Vector3.ZERO, friction)

	velocity = _real_velocity
	move_and_slide()

	# Update animation state based on movement (only if not stroking or recovering)
	if _can_update_movement_animation():
		if animation_direction.length() > 0:
			_set_state(PlayerStateMachine.State.MOVING)
			model.play_run(animation_direction)
		else:
			_set_state(PlayerStateMachine.State.IDLE)



## Apply movement using animation root motion

## Compute movement direction from path
func compute_move_dir() -> Vector3:
	if _consume_target_reached_if_needed(position):
		target_point_reached.emit()

	if _path.size() == 0:
		return Vector3.ZERO

	assert(_path.size() == 1)
	return _get_move_direction(position)


## Queue a movement to target position
func request_move_to(target: Vector3) -> void:
	cancel_movement()
	_path.append(target)


## Cancel all pending movement
func cancel_movement() -> void:
	_path = []


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
		var closest_step: TrajectoryStep = _get_closest_step()
		if not closest_step:
			push_warning("Player._on_target_point_reached: closest trajectory step unavailable")
			return
		Loggie.msg(player_data.last_name + ": ", 
			"Stroke executed closest_step time:", closest_step.time, "_animation_hit_point_time: ", _animation_hit_point_time
		).info()
		var timing = closest_step.time - _animation_hit_point_time
		if timing > 0:
			await get_tree().create_timer(timing).timeout
			closest_step = _get_closest_step()
			if not closest_step:
				push_warning("Player._on_target_point_reached: trajectory changed before stroke")
				return
		_set_state(PlayerStateMachine.State.STROKING)
		model.play_stroke(stroke)



## Stroke System
##################


func queue_stroke(stroke: Stroke) -> bool:
	if not is_instance_valid(ball):
		_sync_ball_from_match_manager()

	if not is_instance_valid(ball):
		return false

	queued_stroke = stroke
	return true

	#Loggie.msg(player_data.last_name + ": ", 
		#"Stroke queued: distance_to_ball=%.2f, anim_hit_frame=%.2f" %
		#[position.distance_to(ball.position), model.get_animation_hit_frame_time(stroke.stroke_type)]
	#).info()

## Execute ball hit with given stroke
func _hit_ball(stroke: Stroke) -> void:
	if not stroke:
		Loggie.msg(player_data.last_name + ": ", "_hit_ball: No queued stroke").info()
		return

	if not is_instance_valid(ball):
		set_active_ball(null)
		cancel_stroke()
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
	_last_consumed_decision = null
	_set_state(PlayerStateMachine.State.IDLE)


## Execute a serve with given stroke
func serve(stroke: Stroke) -> void:
	queued_stroke = stroke
	_set_state(PlayerStateMachine.State.STROKING)
	_lifecycle_bus.start_serving(self, stroke)
	model.play_stroke(stroke)
	# Animation callbacks will handle spawning ball and hitting it


## Called by serve animation to hit the ball
func from_anim_hit_serve() -> void:
	if _is_replay_mode:
		return
	Loggie.msg(player_data.last_name + ": ", "SERVING").info()
	_hit_ball(queued_stroke)
	_lifecycle_bus.complete_serve(self)


## Called by rally stroke animations at the exact hit frame.
## Uses timing/range gates so mistimed strokes can miss.
func _from_anim_hit_ball() -> void:
	if _is_replay_mode:
		return
	if not queued_stroke:
		push_error("no queued stroke")
		return

	if not ball:
		_sync_ball_from_match_manager()

	if not ball:
		cancel_stroke()
		return

	var contact_point: Vector3 = model.get_racket_contact_point(queued_stroke)
	var _distance_to_contact: float = ball.global_position.distance_to(contact_point)
	#if distance_to_contact > hit_range_tolerance_meters:
		#cancel_stroke()
		#return

	#var closest_step: TrajectoryStep = _get_closest_step()
	#if closest_step and abs(closest_step.time) > hit_timing_window_seconds:
		#cancel_stroke()
		#return

	#if snap_ball_to_contact_point_on_anim_hit and distance_to_contact <= snap_max_distance_meters:
		#ball.global_position = contact_point

	_hit_ball(queued_stroke)
	
## Called by serve animation to spawn the ball at toss point
func from_anim_spawn_ball() -> void:
	if _is_replay_mode:
		return
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
	active_ball_changed.emit(b)
	if controller:
		controller.ball_changed(b)


func _sync_ball_from_match_manager() -> void:
	if is_instance_valid(ball):
		return

	var match_manager: MatchManager = get_parent() as MatchManager
	if not match_manager:
		return

	var active_ball: Ball = match_manager.get_active_ball()
	if is_instance_valid(active_ball):
		set_active_ball(active_ball)


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
	if _state_machine.get_state() == PlayerStateMachine.State.STROKING:
		_set_state(PlayerStateMachine.State.RECOVERING)


func _on_state_entered(new_state: int) -> void:
	_apply_state_animation(new_state, velocity)


func _apply_state_animation(state: int, movement_velocity: Vector3) -> void:
	match state:
		PlayerStateMachine.State.IDLE:
			model.play_idle()
		PlayerStateMachine.State.MOVING:
			var run_dir: Vector3 = movement_velocity
			run_dir.y = 0.0
			if run_dir.length() <= 0.001:
				run_dir = Vector3.FORWARD
			model.play_run(run_dir)
		PlayerStateMachine.State.PREPARING_STROKE:
			pass
		PlayerStateMachine.State.STROKING:
			pass
		PlayerStateMachine.State.RECOVERING:
			model.play_recovery()
		PlayerStateMachine.State.UNREACHABLE:
			var fallback_dir: Vector3 = movement_velocity
			fallback_dir.y = 0.0
			if fallback_dir.length() > 0.001:
				model.play_run(fallback_dir)
			else:
				var next_target: Variant = _peek_next_target()
				if next_target != null:
					model.play_run((next_target - position).normalized())


func apply_replay_frame(
	replay_transform: Transform3D,
	replay_velocity: Vector3,
	replay_state: int,
	stroke_payload: Dictionary = {},
	animation_snapshot: Dictionary = {}
) -> void:
	global_transform = replay_transform
	velocity = replay_velocity

	if replay_state == PlayerStateMachine.State.STROKING and _last_replay_visual_state != replay_state:
		if not stroke_payload.is_empty():
			play_replay_stroke(stroke_payload)

	if replay_state == PlayerStateMachine.State.MOVING or replay_state == PlayerStateMachine.State.UNREACHABLE:
		_apply_state_animation(replay_state, replay_velocity)
	elif replay_state != _last_replay_visual_state:
		_apply_state_animation(replay_state, replay_velocity)

	if not animation_snapshot.is_empty():
		model.apply_replay_animation_snapshot(animation_snapshot)

	_last_replay_visual_state = replay_state


func reset_replay_visual_state() -> void:
	_last_replay_visual_state = -1


func set_replay_mode(enabled: bool) -> void:
	_is_replay_mode = enabled


func set_replay_animation_paused(paused: bool) -> void:
	model.set_replay_animation_paused(paused)


func get_replay_animation_snapshot() -> Dictionary:
	return model.get_replay_animation_snapshot()


func play_replay_stroke(stroke_payload: Dictionary) -> void:
	var replay_stroke := Stroke.new()
	replay_stroke.stroke_type = int(stroke_payload.get("stroke_type", Stroke.StrokeType.FOREHAND)) as Stroke.StrokeType
	replay_stroke.stroke_power = float(stroke_payload.get("stroke_power", 0.0))
	replay_stroke.stroke_target = stroke_payload.get("stroke_target", global_position)
	replay_stroke.stroke_spin = stroke_payload.get("stroke_spin", Vector3.ZERO)
	model.play_stroke(replay_stroke)


func _on_lifecycle_phase_changed(previous_phase: int, current_phase: int) -> void:
	lifecycle_phase_changed.emit(previous_phase, current_phase)
	if controller:
		controller.on_lifecycle_phase_changed(previous_phase, current_phase)


func get_lifecycle_bus() -> MatchLifecycleBus:
	return _lifecycle_bus


func get_current_state() -> int:
	if _state_machine:
		return _state_machine.get_state()
	return PlayerStateMachine.State.IDLE


func get_movement_path() -> Array[Vector3]:
	var next_target: Variant = _peek_next_target()
	if next_target == null:
		return []
	return [next_target]


func _consume_target_reached_if_needed(body_position: Vector3) -> bool:
	if _path.size() == 0:
		return false

	if body_position.distance_squared_to(_path[0]) < DISTANCE_THRESHOLD:
		_path.remove_at(0)
		return true

	return false


func _peek_next_target() -> Variant:
	if _path.size() == 0:
		return null
	return _path[0]


func _get_move_direction(body_position: Vector3) -> Vector3:
	if _path.size() == 0:
		return Vector3.ZERO

	var direction: Vector3 = (_path[0] - body_position).normalized()
	direction.y = 0
	return direction


func _get_closest_step() -> TrajectoryStep:
	if not ball:
		return null

	if controller and controller.has_method("get_closest_trajectory_step"):
		return controller.get_closest_trajectory_step(self)
	return null
