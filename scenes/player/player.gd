## Main player entity that handles movement, strokes, and AI/human control
class_name Player
extends CharacterBody3D

## Emitted when player successfully hits the ball
signal ball_hit

## Emitted when a stroke animation (swing and follow-through) has finished
signal stroke_finished

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

const DISTANCE_THRESHOLD: float = 0.01
const STAMINA_STROKE_COST_BASE: float = 5.5
const STAMINA_MOVE_DRAIN_BASE: float = 6.0
## Ball within this distance (m) of the racket contact point at contact: perfect positioning.
const PERFECT_CONTACT_DISTANCE: float = 0.15
## Share of the stroke speed kept at the worst positioning (ball at the edge of the hit range).
const POOR_POSITION_POWER_FACTOR: float = 0.6
## Extra landing error (m) at the worst positioning.
const POOR_POSITION_ERROR_RADIUS: float = 3.0
## Share of the target depth (distance from the net) reached at the worst positioning: a weak
## shot lands shorter instead of being looped up high.
const POOR_POSITION_DEPTH_FACTOR: float = 0.7
## Readiness: a player moving slower than SET_SPEED (m/s) is set for the shot; being set for
## FULL_READINESS_SET_TIME seconds before contact is full readiness.
const SET_SPEED: float = 1.0
const FULL_READINESS_SET_TIME: float = 0.5
## Readiness: seconds the ball flies toward the player before contact. Below RUSHED_FLIGHT_TIME
## (a hard serve or drive) there is no time to attack, from RELAXED_FLIGHT_TIME on (a slow or
## short ball) there is plenty.
const RUSHED_FLIGHT_TIME: float = 0.75
const RELAXED_FLIGHT_TIME: float = 1.35
## Shot rating label: start height above the player (m) and how long it shows (s)
const SHOT_FEEDBACK_HEIGHT: float = 2.2
const SHOT_FEEDBACK_TIME: float = 1.4
## Height (m) by which strokes and serves aim to pass over the net cord
const STROKE_NET_CLEARANCE: float = 0.15
const SERVE_NET_CLEARANCE: float = 0.03

## Controller scene instantiated to drive movement/stroke decisions.
@export var controller_scene: PackedScene
## Static player identity/config data (name, handedness, sounds, stats).
@export var player_data: PlayerData
## Current active ball this player tracks and can hit.
@export var ball: Ball
## Base top speed (m/s) running toward the net; sideways and backward are slower (see
## MovementController) and the player's stats scale it.
@export var move_speed: float = 5.6
## Team slot index used to group players in doubles/splitscreen contexts.
@export var team_index: int = 0
## World-space marker used to visualize shot aim target.
@export var ball_aim_marker: BallAimMarker
## Shows where to stand to meet the incoming ball (for controllers that provide it).
@export var ideal_position_marker: Node3D
## Opposing player reference for serve/rally synchronization.
@export var opponent: Player
## Ball scene used to spawn a toss ball when serving.
@export var serve_ball_scene: PackedScene
## Maximum distance between ball and racket contact point that still counts as a hit.
@export var hit_range_tolerance_meters: float = 1.0
## Maximum stroke playback speed used to reach the ball when the swing starts late.
@export var max_stroke_speed: float = 1.8

## Flat stroke sound effect pool (non-slice hits/grunts fallback).
@export var stroke_sounds_flat: Array[AudioStream]
## Slice stroke sound effect pool used for slice/drop-shot variants.
@export var stroke_sounds_slice: Array[AudioStream]

## Deceleration rate in m/s² without movement input.
@export var friction: float = 12.0
## Base acceleration in m/s² (pros sprint 5 m in ~1.0 s); the player's stats scale it.
@export var acceleration: float = 11.0

## Runtime stat profile copied from player_data for fast gameplay access.
var stats: PlayerRuntimeStats
## Runtime mental state used by tactical and execution systems.
var mental_state: PlayerMentalState
## Stroke waiting for the ball or being swung until racket contact.
var queued_stroke: Stroke = null

var controller: Controller
## Match this player plays in; set by the MatchManager (null outside of a match).
var match_manager: MatchManager

## Angle bisector visualization data for debug drawing
var bisector_service_line_left: Vector3 = Vector3.ZERO
var bisector_service_line_right: Vector3 = Vector3.ZERO
var bisector_direction: Vector3 = Vector3.ZERO
var opponent_hit_position: Vector3 = Vector3.ZERO

var _ball_factory: BallFactory
var _movement: MovementController
## Clip of the queued stroke once its swing has started.
var _swing_clip: StrokeClip = null
## Seconds until the racket is expected to meet the ball; INF while no contact is predicted.
var _seconds_to_contact: float = INF
## Positioning quality in [0, 1] of the last ball hit (1 for serves)
var last_positioning_quality: float = 1.0
## Readiness in [0, 1] of the last ball hit (1 for serves): set early with time to spare.
var last_readiness: float = 1.0
## Seconds the player has been set (moving slower than SET_SPEED).
var _set_time: float = 0.0
## Seconds the active ball has been flying toward this player.
var _incoming_time: float = 0.0
var _feedback_tween: Tween
var _last_consumed_decision: Stroke = null
var _stamina_current: float = 100.0
var _stamina_max: float = 100.0

var _is_replay_mode: bool = false

@onready var model: Model = $Model
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var label_3d: Label3D = $Label3D
@onready var _shot_feedback_label: Label3D = $ShotFeedbackLabel

@onready var _state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var _lifecycle_bus: MatchLifecycleBus = $MatchLifecycleBus


func _ready() -> void:
	assert(player_data != null, "Player._ready: player_data is required")
	mental_state = PlayerMentalState.new()
	mental_state.setup(player_data.stats)
	stats = PlayerRuntimeStats.new()
	stats.setup(player_data.stats, mental_state)
	assert(stats != null, "Player._ready: player_data.stats is required")
	assert(player_data.appearance != null, "Player._ready: player_data.appearance is required")
	_stamina_max = stats.stamina_capacity()
	_stamina_current = _stamina_max
	label_3d.text = player_data.last_name
	model.load_appearance(player_data.appearance)

	# Set logger name for debug logging
	set_meta("logger_name", player_data.last_name)

	_lifecycle_bus.phase_changed.connect(_on_lifecycle_phase_changed)

	_movement = MovementController.new()
	_ball_factory = BallFactory.new(serve_ball_scene)

	model.animator.stroke_marker_reached.connect(_on_stroke_marker_reached)
	model.animator.stroke_finished.connect(_on_stroke_animation_finished)
	controller = controller_scene.instantiate()
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
	_update_readiness(delta)
	_update_stroke_timing()


## Request the input handler to initiate a serve
func request_serve() -> void:
	_lifecycle_bus.begin_serve_setup(self)
	controller.request_serve()


## Setup player with given data and control method
func setup(data: PlayerData, _ai_controlled: bool) -> void:
	player_data = data
	if stats:
		stats.setup(player_data.stats, mental_state)


## Stop all player actions and clean up state
func stop() -> void:
	_halt()
	cancel_stroke()
	set_active_ball(null)
	_lifecycle_bus.end_point(self)


## Movement System
####################


## Puts the player at a court position facing the net, without any leftover movement.
func place_at(target_position: Vector3) -> void:
	_halt()
	global_position = target_position
	rotation.y = PI if target_position.z < 0.0 else 0.0


## Drops the movement target and all momentum.
func _halt() -> void:
	_movement.stop()
	velocity = Vector3.ZERO


## Apply movement in given direction
func apply_movement(direction: Vector3, delta: float) -> void:
	var stamina01: float = get_stamina_ratio()
	_movement.set_friction(friction)
	var facing: Vector3 = -global_basis.z
	facing.y = 0.0
	velocity = _movement.tick(
		direction, facing.normalized(), stats, stamina01, move_speed, acceleration
	)
	move_and_slide()

	model.animator.set_locomotion(_locomotion_blend(velocity))
	if not _state_machine.is_stroke_in_progress():
		if direction.length() > 0:
			_set_state(PlayerStateMachine.State.MOVING)
		else:
			_set_state(PlayerStateMachine.State.IDLE)

	_update_stamina(direction, delta)


## Locomotion blend position (x = right, y = forward) for a world-space velocity.
func _locomotion_blend(world_velocity: Vector3) -> Vector2:
	var local_velocity: Vector3 = global_basis.inverse() * world_velocity
	var blend := Vector2(local_velocity.x, -local_velocity.z) / move_speed
	return blend.limit_length(1.0)


## Compute movement direction from path
func compute_move_dir() -> Vector3:
	if _movement.check_and_consume_reached(position, DISTANCE_THRESHOLD):
		target_point_reached.emit()

	return _movement.compute_direction(position, move_speed)


## Queue a movement to target position
func request_move_to(target: Vector3) -> void:
	_movement.request_move_to(target)


## Cancel all pending movement
func cancel_movement() -> void:
	_movement.cancel()


## Move to defensive position after stroke animation finishes
func move_to_defensive_position(target_position: Vector3) -> void:
	await stroke_finished
	request_move_to(target_position)


## Stroke System
##################


## Queue a rally stroke. It is swung automatically so that the animation's `hit`
## marker coincides with the ball reaching the racket contact point.
## Returns false while a swing is already on its way to contact.
func queue_stroke(stroke: Stroke) -> bool:
	if _swing_clip:
		return false

	if not is_instance_valid(ball):
		_sync_ball_from_match_manager()

	if not is_instance_valid(ball):
		return false

	queued_stroke = stroke
	if _state_machine.get_state() != PlayerStateMachine.State.STROKING:
		_set_state(PlayerStateMachine.State.PREPARING_STROKE)
	return true


## Seconds until the racket is expected to meet the ball; INF while no contact is predicted.
func get_seconds_to_contact() -> float:
	return _seconds_to_contact


## Start the swing of the queued stroke once the ball is within the clip's hit time.
func _update_stroke_timing() -> void:
	if _swing_clip:
		_seconds_to_contact -= get_physics_process_delta_time()
		return
	if not queued_stroke or not is_instance_valid(ball):
		_seconds_to_contact = INF
		return

	var clip: StrokeClip = model.get_stroke_clip(queued_stroke)
	var contact_point: Vector3 = clip.global_position
	if _is_ball_moving_away_from(contact_point):
		# Ball already passed the contact point: the stroke is too late.
		cancel_stroke()
		return

	var time_to_contact: float = _predict_time_to_contact(contact_point)
	if time_to_contact < 0.0:
		_seconds_to_contact = INF
		return
	# A fired OneShot starts advancing one animation frame later.
	time_to_contact -= get_process_delta_time()
	_seconds_to_contact = time_to_contact

	var hit_time: float = model.animator.get_marker_time(clip.animation, PlayerAnimator.HIT_MARKER)
	if time_to_contact > hit_time:
		return

	# Late swings are sped up so the hit marker still lines up with the ball; when even the
	# fastest swing is too slow, the swing starts part of the way through (a shortened backswing).
	var speed: float = clampf(hit_time / maxf(time_to_contact, 0.001), 1.0, max_stroke_speed)
	var start_time: float = maxf(hit_time - time_to_contact * max_stroke_speed, 0.0)
	_start_swing(clip, speed, start_time)


## Plays the stroke clip from `start_time` (s) at `speed`.
func _start_swing(clip: StrokeClip, speed: float, start_time: float = 0.0) -> void:
	_swing_clip = clip
	var hit_time: float = model.animator.get_marker_time(clip.animation, PlayerAnimator.HIT_MARKER)
	_seconds_to_contact = (hit_time - start_time) / speed
	_set_state(PlayerStateMachine.State.STROKING)
	model.animator.play_stroke(clip.animation, speed, start_time)


func _is_ball_moving_away_from(contact_point: Vector3) -> bool:
	var offset: float = ball.global_position.z - contact_point.z
	return offset * ball.velocity.z > 0.0


## Seconds until the ball crosses the depth (z) of the contact point before its second bounce,
## or -1 if it does not. The contact point moves along with the player running to its target.
func _predict_time_to_contact(contact_point: Vector3) -> float:
	var side: float = signf(ball.global_position.z - contact_point.z)
	var previous_offset: float = ball.global_position.z - contact_point.z
	var previous_time: float = 0.0
	var trajectory: Array[TrajectoryStep] = ball.predict_trajectory(
		GameConstants.TRAJECTORY_PREDICTION_STEPS,
		GameConstants.TRAJECTORY_TIME_STEP,
		{"store_result": false}
	)
	for step in trajectory:
		if step.bounces > 1:
			return -1.0
		var offset: float = step.point.z - (contact_point.z + _body_travel(step.time).z)
		if signf(offset) != side:
			var crossing: float = previous_offset / (previous_offset - offset)
			return lerpf(previous_time, step.time, crossing)
		previous_offset = offset
		previous_time = step.time
	return -1.0


## How far (m) the player moves in `seconds` at its current velocity, at most to its movement
## target.
func _body_travel(seconds: float) -> Vector3:
	var travel := Vector3(velocity.x, 0.0, velocity.z) * seconds
	var path: Array[Vector3] = _movement.get_path()
	if path.is_empty():
		return travel
	var to_target: Vector3 = path[0] - global_position
	to_target.y = 0.0
	return travel.limit_length(to_target.length())


## How far (m) the ball passes from the racket contact point during this physics tick.
func _contact_distance(contact_point: Vector3) -> float:
	var travel: Vector3 = ball.velocity / Engine.physics_ticks_per_second
	var closest: Vector3 = Geometry3D.get_closest_point_to_segment(
		contact_point, ball.global_position - travel, ball.global_position + travel
	)
	return closest.distance_to(contact_point)


## Positioning quality in [0, 1] for a ball meeting the racket `contact_distance` meters off
## the contact point: 1 within PERFECT_CONTACT_DISTANCE, 0 at the edge of the hit range.
func _positioning_quality(contact_distance: float) -> float:
	var off_by: float = contact_distance - PERFECT_CONTACT_DISTANCE
	var tolerance: float = hit_range_tolerance_meters - PERFECT_CONTACT_DISTANCE
	return 1.0 - clampf(off_by / tolerance, 0.0, 1.0)


## Readiness in [0, 1] at contact: how long the player has been set and how much time the
## incoming ball gave; the worse of both counts.
func _readiness() -> float:
	var set_quality: float = clampf(_set_time / FULL_READINESS_SET_TIME, 0.0, 1.0)
	var time_quality: float = clampf(
		(_incoming_time - RUSHED_FLIGHT_TIME) / (RELAXED_FLIGHT_TIME - RUSHED_FLIGHT_TIME),
		0.0,
		1.0
	)
	return minf(set_quality, time_quality)


func _update_readiness(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_set_time = _set_time + delta if horizontal_speed < SET_SPEED else 0.0
	var ball_incoming: bool = (
		is_instance_valid(ball) and ball.velocity.z * signf(global_position.z) > 0.0
	)
	_incoming_time = _incoming_time + delta if ball_incoming else 0.0


## Applies how well the ball was met: the stroke's attack pace only comes through in full when
## the player is in position and ready; out of position the stroke is also weakened, shortened
## and scattered.
func _apply_contact_quality(stroke: Stroke, positioning: float, readiness: float) -> void:
	stroke.stroke_power += stroke.attack_power * positioning * readiness
	stroke.stroke_power *= lerpf(POOR_POSITION_POWER_FACTOR, 1.0, positioning)
	stroke.stroke_target.z *= lerpf(POOR_POSITION_DEPTH_FACTOR, 1.0, positioning)
	var error_radius: float = POOR_POSITION_ERROR_RADIUS * (1.0 - positioning)
	var error: Vector2 = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * error_radius
	stroke.stroke_target += Vector3(error.x, 0.0, error.y)


func _on_stroke_marker_reached(marker: StringName) -> void:
	if _is_replay_mode:
		return

	match marker:
		PlayerAnimator.TOSS_MARKER:
			_spawn_serve_ball()
		PlayerAnimator.HIT_MARKER:
			_on_stroke_contact()


## Racket reaches the contact point of the swinging stroke.
func _on_stroke_contact() -> void:
	var stroke: Stroke = queued_stroke
	var clip: StrokeClip = _swing_clip
	if not stroke or not clip:
		return

	if stroke.stroke_type == Stroke.StrokeType.SERVE:
		last_positioning_quality = 1.0
		last_readiness = 1.0
		_hit_ball(stroke)
		_lifecycle_bus.complete_serve(self)
		return

	if not is_instance_valid(ball):
		cancel_stroke()
		return
	var contact_distance: float = _contact_distance(clip.global_position)
	if contact_distance > hit_range_tolerance_meters:
		cancel_stroke()
		return
	last_positioning_quality = _positioning_quality(contact_distance)
	last_readiness = _readiness()
	_apply_contact_quality(stroke, last_positioning_quality, last_readiness)
	_hit_ball(stroke)


## Execute ball hit with given stroke
func _hit_ball(stroke: Stroke) -> void:
	if not stroke:
		return

	if not is_instance_valid(ball):
		set_active_ball(null)
		cancel_stroke()
		return

	var is_serve: bool = stroke.stroke_type == Stroke.StrokeType.SERVE
	# Spin is defined in [-1, 1]; skill and timing bonuses cannot push it further.
	var spin: Vector3 = stroke.stroke_spin.clamp(-Vector3.ONE, Vector3.ONE)
	var stroke_velocity: Vector3 = ball.calculate_velocity(
		ball.position,
		stroke.stroke_target,
		-sign(position.z) * stroke.stroke_power,
		spin,
		SERVE_NET_CLEARANCE if is_serve else STROKE_NET_CLEARANCE
	)

	ball.apply_stroke(stroke_velocity, spin)
	_consume_stamina(_stroke_stamina_cost(stroke))
	play_stroke_sound(stroke)
	ball_hit.emit()
	cancel_stroke()


func get_stamina_ratio() -> float:
	if _stamina_max <= 0.0:
		return 1.0
	return clampf(_stamina_current / _stamina_max, 0.0, 1.0)


func _update_stamina(direction: Vector3, delta: float) -> void:
	if delta <= 0.0:
		return

	var stamina01: float = get_stamina_ratio()
	if direction.length_squared() > 0.001:
		var movement_load: float = clampf(
			_movement.get_velocity().length() / maxf(move_speed, 0.001), 0.0, 1.4
		)
		var preservation: float = stats.stamina_preservation()
		var drain_rate: float = (
			STAMINA_MOVE_DRAIN_BASE * movement_load * lerpf(1.25, 0.65, preservation)
		)
		_consume_stamina(drain_rate * delta)
		stats.set_stamina_ratio(get_stamina_ratio())
		return

	var recovery_rate: float = stats.stamina_recovery_rate() * lerpf(0.8, 1.2, stamina01)
	_restore_stamina(recovery_rate * delta)
	stats.set_stamina_ratio(get_stamina_ratio())


func _stroke_stamina_cost(stroke: Stroke) -> float:
	if not stroke:
		return STAMINA_STROKE_COST_BASE

	var stroke_load: float = clampf(stroke.stroke_power / 36.0, 0.0, 1.4)
	var topspin_load: float = clampf(abs(stroke.stroke_spin.y) / 12.0, 0.0, 1.0)
	var preservation: float = stats.stamina_preservation()
	return (
		STAMINA_STROKE_COST_BASE
		* (0.85 + stroke_load * 0.9 + topspin_load * 0.35)
		* lerpf(1.2, 0.75, preservation)
	)


func _consume_stamina(amount: float) -> void:
	_stamina_current = maxf(0.0, _stamina_current - maxf(amount, 0.0))
	if stats:
		stats.set_stamina_ratio(get_stamina_ratio())


func _restore_stamina(amount: float) -> void:
	_stamina_current = minf(_stamina_max, _stamina_current + maxf(amount, 0.0))
	if stats:
		stats.set_stamina_ratio(get_stamina_ratio())


## Drop the queued stroke. A swing already playing finishes its animation.
func cancel_stroke() -> void:
	queued_stroke = null
	_swing_clip = null
	_seconds_to_contact = INF
	if _state_machine.get_state() == PlayerStateMachine.State.PREPARING_STROKE:
		_set_state(PlayerStateMachine.State.IDLE)


## Execute a serve with given stroke. The serve animation's `toss` marker spawns the ball,
## its `hit` marker hits it.
func serve(stroke: Stroke) -> void:
	queued_stroke = stroke
	_lifecycle_bus.start_serving(self, stroke)
	_start_swing(model.get_stroke_clip(stroke), 1.0)


func _spawn_serve_ball() -> void:
	ball = _ball_factory.create_ball(position + model.toss_point, Vector3(0, 5, 0))
	if not ball:
		return
	get_parent().add_child(ball)
	set_active_ball(ball)
	if opponent:
		opponent.set_active_ball(ball)
	ball_spawned.emit(ball)


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

	if stroke.stroke_type == Stroke.StrokeType.BACKHAND_SLICE or stroke.is_drop():
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

	if not match_manager:
		return

	var active_ball: Ball = match_manager.get_active_ball()
	if is_instance_valid(active_ball):
		set_active_ball(active_ball)


## Update UI based on controller state (uniform interface for all controllers)
func _update_controller_ui() -> void:
	if not controller:
		return

	var ideal_position: Variant = controller.get_ideal_position()
	ideal_position_marker.visible = ideal_position != null
	if ideal_position != null:
		ideal_position_marker.global_position = ideal_position

	# Check if controller wants to show aim marker
	if controller.should_show_aim_marker():
		var aim_position: Variant = controller.get_aim_marker_position()
		if aim_position != null:
			ball_aim_marker.global_position = aim_position
			ball_aim_marker.set_radius(controller.get_aim_marker_radius())
			ball_aim_marker.set_highlighted(controller.is_aim_marker_highlighted())
			ball_aim_marker.visible = true
	else:
		ball_aim_marker.visible = false


## Called when stroke animation finishes
func _on_stroke_animation_finished() -> void:
	if _is_replay_mode:
		return

	if queued_stroke:
		_set_state(PlayerStateMachine.State.PREPARING_STROKE)
	else:
		_set_state(PlayerStateMachine.State.IDLE)
	stroke_finished.emit()


func apply_replay_frame(
	replay_transform: Transform3D, replay_velocity: Vector3, animation_snapshot: Dictionary
) -> void:
	global_transform = replay_transform
	velocity = replay_velocity
	model.animator.apply_snapshot(animation_snapshot)


func set_replay_mode(enabled: bool) -> void:
	_is_replay_mode = enabled


func set_replay_animation_paused(paused: bool) -> void:
	model.animator.active = not paused


func get_replay_animation_snapshot() -> Dictionary:
	return model.animator.get_snapshot()


func _on_lifecycle_phase_changed(previous_phase: int, current_phase: int) -> void:
	lifecycle_phase_changed.emit(previous_phase, current_phase)
	if controller:
		controller.on_lifecycle_phase_changed(previous_phase, current_phase)


## Called by match_manager after a point concludes to update mental state.
func on_point_result(won: bool) -> void:
	if mental_state:
		if won:
			mental_state.on_point_won()
		else:
			mental_state.on_point_lost()


## Shows a short rating of the last shot (e.g. "PERFECT!") rising above the player.
func show_shot_feedback(text: String, color: Color) -> void:
	_shot_feedback_label.text = text
	_shot_feedback_label.modulate = color
	_shot_feedback_label.position.y = SHOT_FEEDBACK_HEIGHT
	_shot_feedback_label.visible = true
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.tween_property(
		_shot_feedback_label, "position:y", SHOT_FEEDBACK_HEIGHT + 0.8, SHOT_FEEDBACK_TIME
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_feedback_tween.tween_property(
		_shot_feedback_label, "modulate:a", 0.0, SHOT_FEEDBACK_TIME * 0.5
	).set_delay(SHOT_FEEDBACK_TIME * 0.5)
	_feedback_tween.chain().tween_callback(_shot_feedback_label.hide)


## Whether the next shot of this player is the return of a serve.
func is_returning_serve() -> bool:
	return match_manager != null and match_manager.match_data.rally_length == 1


func get_lifecycle_bus() -> MatchLifecycleBus:
	return _lifecycle_bus


func get_current_state() -> int:
	if _state_machine:
		return _state_machine.get_state()
	return PlayerStateMachine.State.IDLE


func get_movement_path() -> Array[Vector3]:
	return _movement.get_path()
