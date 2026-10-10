## Main player entity that handles movement, strokes, and AI/human control
class_name Player
extends CharacterBody3D

## Emitted when player successfully hits the ball
signal ball_hit

## Emitted when a stroke animation (swing and follow-through) has finished
signal stroke_finished

## Emitted when the ball is tossed for a serve
signal ball_spawned(ball: Ball)

const DISTANCE_THRESHOLD: float = 0.01
const STAMINA_STROKE_COST_BASE: float = 5.5
const STAMINA_MOVE_DRAIN_BASE: float = 6.0
## Ball within this distance (m) of the racket contact point at contact: perfect positioning.
const PERFECT_CONTACT_DISTANCE: float = 0.15
## Extra landing error (m) at the worst control.
const POOR_POSITION_ERROR_RADIUS: float = 3.0
## Share of the target depth (distance from the net) reached at the worst control: a weak shot
## lands shorter instead of being looped up high.
const POOR_POSITION_DEPTH_FACTOR: float = 0.55
## Flight time of a shot at the worst control as a share of the clean shot's, drawn per shot. The
## shorter ball keeps about the clean flight time, so it is slower without looping up: some come
## a little flatter, some a little higher.
const POOR_POSITION_FLIGHT_TIME: Vector2 = Vector2(0.95, 1.2)
## Share of the spin kept at the worst control: a mishit comes off the racket flat, so it does
## not loop up.
const POOR_POSITION_SPIN_FACTOR: float = 0.35
## Depth pressure: a deep ball pushes the player back and rushes the shot. It rises from none
## for a ball bouncing DEEP_BALL_START (m from the net) to full at the baseline, and for a
## serve over the last DEEP_SERVE_RANGE (m) before the service line.
const DEEP_BALL_START: float = 8.0
const DEEP_SERVE_RANGE: float = 2.5
## Share of the shot control a fully deep ball takes away, for the weakest and for the best
## shot control. A deep ball cannot be attacked at all.
const DEEP_BALL_CONTROL_LOSS: Vector2 = Vector2(0.6, 0.35)
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
## Share of the incoming ball's speed a volley sends back: a punch volley redirects the pace,
## a drop volley absorbs it.
const VOLLEY_PACE_TRANSFER: float = 0.55
const DROP_VOLLEY_PACE_TRANSFER: float = 0.1
## Volley contact heights (m): a ball at LOW_VOLLEY_HEIGHT or lower has to be lifted over the
## net, so it is played slower (LOW_VOLLEY_PACE_FACTOR) and with more backspin; above the net
## cord it can be hit down with the put-away pace, fully from HIGH_VOLLEY_HEIGHT on, and flatter.
const LOW_VOLLEY_HEIGHT: float = 0.4
const HIGH_VOLLEY_HEIGHT: float = 1.7
const LOW_VOLLEY_PACE_FACTOR: float = 0.75
const LOW_VOLLEY_SPIN_FACTOR: float = 2.0
const HIGH_VOLLEY_SPIN_FACTOR: float = 0.3
## Height (m) by which strokes and serves aim to pass over the net cord
const STROKE_NET_CLEARANCE: float = 0.15
const SERVE_NET_CLEARANCE: float = 0.03
## Moving backward faster than BACKWARD_RUN_SPEED (m/s), within about 60 degrees of straight
## back (BACKWARD_RUN_ALIGNMENT: share of the speed pointing backward), the player turns and runs;
## slower than BACKPEDAL_SPEED it faces the net again and backpedals.
const BACKWARD_RUN_SPEED: float = 2.0
const BACKPEDAL_SPEED: float = 1.5
const BACKWARD_RUN_ALIGNMENT: float = 0.5

## Static player identity/config data (name, handedness, sounds, stats).
@export var player_data: PlayerData
## Base top speed (m/s) running toward the net; sideways and backward are slower (see
## MovementController) and the player's stats scale it.
@export var move_speed: float = 5.6
## Team slot index; picks the input device (or AI) controlling this player.
@export var team_index: int = 0
## World-space marker used to visualize shot aim target.
@export var ball_aim_marker: BallAimMarker
## Shows where to stand to meet the incoming ball (for controllers that provide it), colored by
## how well the player stands there.
@export var ideal_position_marker: IdealPositionMarker
## Opposing player reference for serve/rally synchronization.
@export var opponent: Player
## Ball scene spawned as the toss ball when serving.
@export var ball_scene: PackedScene
## Maximum distance between ball and racket contact point that still counts as a hit.
@export var hit_range_tolerance_meters: float = 1.0
## Maximum stroke playback speed used to reach the ball when the swing starts late.
@export var max_stroke_speed: float = 1.8

## Flat stroke sound effect pool (strokes without a grunt).
@export var stroke_sounds_flat: Array[AudioStream]
## Slice stroke sound effect pool used for slice/drop-shot variants.
@export var stroke_sounds_slice: Array[AudioStream]

## Deceleration rate in m/s² without movement input.
@export var friction: float = 12.0
## Base acceleration in m/s² (pros sprint 5 m in ~1.0 s); the player's stats scale it.
@export var acceleration: float = 11.0

## Current active ball this player tracks and can hit.
var ball: Ball
## Runtime stat profile: the player's stats affected by stamina and pressure.
var stats: PlayerRuntimeStats
## Runtime mental state used by tactical and execution systems.
var mental_state: PlayerMentalState
## Stroke waiting for the ball or being swung until racket contact.
var queued_stroke: Stroke = null

var controller: Controller
## Match or training this player plays in; set by the session.
var session: PlaySession
## Positioning quality in [0, 1] of the last ball hit (1 for serves)
var last_positioning_quality: float = 1.0

## Angle bisector visualization data for debug drawing
var bisector_service_line_left: Vector3 = Vector3.ZERO
var bisector_service_line_right: Vector3 = Vector3.ZERO
var bisector_direction: Vector3 = Vector3.ZERO
var opponent_hit_position: Vector3 = Vector3.ZERO

var _movement := MovementController.new()
## Clip of the queued stroke once its swing has started.
var _swing_clip: StrokeClip = null
## Seconds until the racket is expected to meet the ball; INF while no contact is predicted.
var _seconds_to_contact: float = INF
## Seconds the player has been set (moving slower than SET_SPEED).
var _set_time: float = 0.0
## Seconds the active ball has been flying toward this player.
var _incoming_time: float = 0.0
var _feedback_tween: Tween
var _last_consumed_decision: Stroke = null
var _stamina: float = 1.0
## Whether the player has turned to run backward
var _running_backward: bool = false

var _is_replay_mode: bool = false

@onready var model: Model = $Model
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var label_3d: Label3D = $Label3D
@onready var _shot_feedback_label: Label3D = $ShotFeedbackLabel

@onready var _state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var _lifecycle_bus: MatchLifecycleBus = $MatchLifecycleBus


func _ready() -> void:
	mental_state = PlayerMentalState.new(player_data.stats)
	stats = PlayerRuntimeStats.new(player_data.stats, mental_state)
	_stamina = stats.stamina_capacity()
	label_3d.text = player_data.last_name
	model.load_appearance(player_data.appearance)
	set_meta("logger_name", player_data.last_name)

	_lifecycle_bus.phase_changed.connect(_on_lifecycle_phase_changed)
	model.animator.stroke_marker_reached.connect(_on_stroke_marker_reached)
	model.animator.stroke_finished.connect(_on_stroke_animation_finished)
	if GlobalGameData.is_human_controlled(team_index):
		controller = HumanController.new(self)
	else:
		controller = AiController.new(self)
	add_child(controller)


## Set player state through dedicated state machine
func _set_state(new_state: PlayerStateMachine.State) -> void:
	_state_machine.transition_to(new_state)


func _process(delta: float) -> void:
	controller.update(delta)
	_update_controller_ui()
	_consume_controller_stroke()


## Serves or queues the stroke the controller decided on, once per decision.
func _consume_controller_stroke() -> void:
	var stroke: Stroke = controller.get_stroke()
	if not stroke or stroke == _last_consumed_decision:
		return

	if stroke.stroke_type == Stroke.StrokeType.SERVE:
		serve(stroke)
	elif not queue_stroke(stroke):
		return
	_last_consumed_decision = stroke


func _physics_process(delta: float) -> void:
	apply_movement(controller.get_move_direction(), delta)
	_update_readiness(delta)
	_update_stroke_timing()


## Request the input handler to initiate a serve
func request_serve() -> void:
	_lifecycle_bus.begin_serve_setup(self)
	controller.request_serve()


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
	_running_backward = false
	model.set_body_yaw(0.0)
	global_position = target_position
	rotation.y = PI if target_position.z < 0.0 else 0.0


## Drops the movement target and all momentum.
func _halt() -> void:
	_movement.stop()
	velocity = Vector3.ZERO


## Apply movement in given direction
func apply_movement(direction: Vector3, delta: float) -> void:
	velocity = _movement.tick(
		direction, _body_facing(), stats, get_stamina_ratio(), move_speed, acceleration, friction
	)
	move_and_slide()

	var body_yaw_target: float = _body_yaw_target()
	model.turn_body_toward(body_yaw_target, delta)
	model.animator.set_locomotion(_locomotion_velocity(velocity, body_yaw_target), delta)
	if not _state_machine.is_stroke_in_progress():
		if direction.length() > 0:
			_set_state(PlayerStateMachine.State.MOVING)
		else:
			_set_state(PlayerStateMachine.State.IDLE)

	_update_stamina(direction, delta)


## Yaw (rad) the body turns to, relative to the player's facing: toward the running direction
## when running backward, otherwise (and always during a stroke) toward the net.
func _body_yaw_target() -> float:
	var local_velocity: Vector3 = global_basis.inverse() * velocity
	var horizontal := Vector2(local_velocity.x, local_velocity.z)
	var speed: float = horizontal.length()
	if _state_machine.is_stroke_in_progress():
		_running_backward = false
	elif _running_backward:
		_running_backward = speed > BACKPEDAL_SPEED and local_velocity.z > 0.0
	else:
		_running_backward = (
			speed > BACKWARD_RUN_SPEED and local_velocity.z > BACKWARD_RUN_ALIGNMENT * speed
		)
	if not _running_backward:
		return 0.0
	# The body faces -z at yaw 0.
	return atan2(-local_velocity.x, -local_velocity.z)


## Velocity (m/s, x = right, y = forward) relative to where the body turns to (`body_yaw`), for
## the locomotion animation: a body turning to run already runs, rather than sweeping through the
## sideways steps while it turns.
func _locomotion_velocity(world_velocity: Vector3, body_yaw: float) -> Vector2:
	var body_basis: Basis = global_basis * Basis(Vector3.UP, body_yaw)
	var local_velocity: Vector3 = body_basis.inverse() * world_velocity
	return Vector2(local_velocity.x, -local_velocity.z)


## Direction toward the movement target at most at `speed_factor` of the top speed (see
## MovementController.compute_direction).
func compute_move_dir(speed_factor: float = 1.0) -> Vector3:
	_movement.check_and_consume_reached(position, DISTANCE_THRESHOLD)
	return _movement.compute_direction(
		position, _body_facing(), stats, get_stamina_ratio(), move_speed, speed_factor
	)


## Horizontal direction the body faces (turned e.g. to run backward); the player runs fastest
## that way.
func _body_facing() -> Vector3:
	var facing: Vector3 = -(global_basis * Basis(Vector3.UP, model.body_yaw)).z
	facing.y = 0.0
	return facing.normalized()


## Horizontal direction the player faces (toward the net).
func _facing() -> Vector3:
	var facing: Vector3 = -global_basis.z
	facing.y = 0.0
	return facing.normalized()


## Seconds this player needs from a standstill to run to `target` and stop there, at
## `speed_factor` of its top speed (see MovementController.reach_time).
func time_to_reach(target: Vector3, speed_factor: float = 1.0) -> float:
	var offset: Vector3 = target - global_position
	offset.y = 0.0
	return _movement.reach_time(
		offset, _facing(), stats, get_stamina_ratio(), move_speed, acceleration, speed_factor
	)


## Queue a movement to target position
func request_move_to(target: Vector3) -> void:
	_movement.request_move_to(target)


## Cancel all pending movement
func cancel_movement() -> void:
	_movement.cancel()


## Move to defensive position after stroke animation finishes, unless the player already
## moves to meet the next ball by then.
func move_to_defensive_position(target_position: Vector3) -> void:
	await stroke_finished
	if queued_stroke:
		return
	request_move_to(target_position)


## Stroke System
##################


## Queue a rally stroke. It is swung automatically so that the animation's `hit`
## marker coincides with the ball reaching the racket contact point.
## Returns false while a swing is already on its way to contact.
func queue_stroke(stroke: Stroke) -> bool:
	if _swing_clip or not is_instance_valid(ball):
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
	# The swing has to face the net to meet the ball at the clip's contact point.
	model.set_body_yaw(0.0)
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
	for step in ball.predict_trajectory():
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
	var target: Variant = _movement.get_target()
	if target == null:
		return travel
	var to_target: Vector3 = target - global_position
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
func positioning_quality(contact_distance: float) -> float:
	var off_by: float = contact_distance - PERFECT_CONTACT_DISTANCE
	var tolerance: float = hit_range_tolerance_meters - PERFECT_CONTACT_DISTANCE
	return 1.0 - clampf(off_by / tolerance, 0.0, 1.0)


## Readiness in [0, 1] at contact: how long the player has been set and how much time the
## incoming ball gave; the worse of both counts.
func _readiness() -> float:
	var set_quality: float = clampf(_set_time / FULL_READINESS_SET_TIME, 0.0, 1.0)
	var time_quality: float = clampf(
		(_incoming_time - RUSHED_FLIGHT_TIME) / (RELAXED_FLIGHT_TIME - RUSHED_FLIGHT_TIME), 0.0, 1.0
	)
	return minf(set_quality, time_quality)


func _update_readiness(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_set_time = _set_time + delta if horizontal_speed < SET_SPEED else 0.0
	var ball_incoming: bool = (
		is_instance_valid(ball) and ball.velocity.z * signf(global_position.z) > 0.0
	)
	_incoming_time = _incoming_time + delta if ball_incoming else 0.0


## Pressure in [0, 1] of a ball that bounced `bounce_z` (m) from the net: none for a ball
## landing short, full for one landing on the baseline (for a serve: on the service line).
static func depth_pressure(bounce_z: float, is_return: bool) -> float:
	var start: float = (
		GameConstants.SERVICE_LINE - DEEP_SERVE_RANGE if is_return else DEEP_BALL_START
	)
	var end: float = GameConstants.SERVICE_LINE if is_return else GameConstants.COURT_LENGTH_HALF
	return clampf(inverse_lerp(start, end, absf(bounce_z)), 0.0, 1.0)


## Applies how well the ball was met (`control`: the positioning, lowered by a deep incoming
## ball): the stroke's attack pace only comes through in full with full control and its full
## share (readiness, or the contact height of a volley); with poor control the stroke is also
## shortened, flattened and scattered, and weakened so that it takes about as long as the clean
## shot over its shorter distance (see POOR_POSITION_FLIGHT_TIME).
func _apply_contact_quality(stroke: Stroke, control: float, attack_share: float) -> void:
	stroke.stroke_power += stroke.attack_power * control * attack_share
	var flight_time: float = (
		_forward_distance(stroke.stroke_target)
		/ stroke.stroke_power
		* lerpf(randf_range(POOR_POSITION_FLIGHT_TIME.x, POOR_POSITION_FLIGHT_TIME.y), 1.0, control)
	)
	stroke.stroke_target.z *= lerpf(POOR_POSITION_DEPTH_FACTOR, 1.0, control)
	stroke.stroke_spin.y *= lerpf(POOR_POSITION_SPIN_FACTOR, 1.0, control)
	var error_radius: float = POOR_POSITION_ERROR_RADIUS * (1.0 - control)
	var error: Vector2 = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * error_radius
	stroke.stroke_target += Vector3(error.x, 0.0, error.y)
	stroke.stroke_power = minf(
		stroke.stroke_power, _forward_distance(stroke.stroke_target) / flight_time
	)


## Distance (m) along the court's length from the ball to `target`.
func _forward_distance(target: Vector3) -> float:
	return absf(target.z - ball.global_position.z)


## A volley is a short punch without a backswing: its pace is mostly the incoming ball's pace
## sent back. A ball below the net cord has to be lifted, so it is played slower and with more
## backspin; a high ball is hit flatter.
func _apply_volley_contact(stroke: Stroke, contact_height: float) -> void:
	var transfer: float = DROP_VOLLEY_PACE_TRANSFER if stroke.is_drop() else VOLLEY_PACE_TRANSFER
	stroke.stroke_power += ball.velocity.length() * transfer
	var lift: float = clampf(
		inverse_lerp(LOW_VOLLEY_HEIGHT, Ball.NET_CENTER_HEIGHT, contact_height), 0.0, 1.0
	)
	stroke.stroke_power *= lerpf(LOW_VOLLEY_PACE_FACTOR, 1.0, lift)
	var height01: float = clampf(
		inverse_lerp(LOW_VOLLEY_HEIGHT, HIGH_VOLLEY_HEIGHT, contact_height), 0.0, 1.0
	)
	stroke.stroke_spin.y *= lerpf(LOW_VOLLEY_SPIN_FACTOR, HIGH_VOLLEY_SPIN_FACTOR, height01)


## Share in [0, 1] of a volley's put-away pace: only a ball above the net cord can be hit down.
static func volley_put_away_share(contact_height: float) -> float:
	return clampf(
		inverse_lerp(Ball.NET_CENTER_HEIGHT, HIGH_VOLLEY_HEIGHT, contact_height), 0.0, 1.0
	)


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
	last_positioning_quality = positioning_quality(contact_distance)
	var control: float = last_positioning_quality
	var attack_share: float = _readiness()
	if stroke.is_volley():
		var contact_height: float = ball.global_position.y
		_apply_volley_contact(stroke, contact_height)
		attack_share = volley_put_away_share(contact_height)
	else:
		var pressure: float = depth_pressure(ball.last_bounce_position.z, is_returning_serve())
		var control_loss: float = lerpf(
			DEEP_BALL_CONTROL_LOSS.x,
			DEEP_BALL_CONTROL_LOSS.y,
			stats.shot_control01(get_stamina_ratio())
		)
		control *= 1.0 - pressure * control_loss
		attack_share *= 1.0 - pressure
	_apply_contact_quality(stroke, control, attack_share)
	_hit_ball(stroke)


## Execute ball hit with given stroke
func _hit_ball(stroke: Stroke) -> void:
	if not is_instance_valid(ball):
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
	_change_stamina(-_stroke_stamina_cost(stroke))
	play_stroke_sound(stroke)
	ball_hit.emit()
	cancel_stroke()


func get_stamina_ratio() -> float:
	return _stamina / stats.stamina_capacity()


func _update_stamina(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.001:
		var movement_load: float = clampf(_movement.get_velocity().length() / move_speed, 0.0, 1.4)
		var drain_rate: float = (
			STAMINA_MOVE_DRAIN_BASE
			* movement_load
			* lerpf(1.25, 0.65, stats.stamina_preservation())
		)
		_change_stamina(-drain_rate * delta)
	else:
		var recovery_rate: float = (
			stats.stamina_recovery_rate() * lerpf(0.8, 1.2, get_stamina_ratio())
		)
		_change_stamina(recovery_rate * delta)


func _stroke_stamina_cost(stroke: Stroke) -> float:
	var stroke_load: float = clampf(stroke.stroke_power / 36.0, 0.0, 1.4)
	var topspin_load: float = clampf(absf(stroke.stroke_spin.y) / 12.0, 0.0, 1.0)
	return (
		STAMINA_STROKE_COST_BASE
		* (0.85 + stroke_load * 0.9 + topspin_load * 0.35)
		* lerpf(1.2, 0.75, stats.stamina_preservation())
	)


func _change_stamina(amount: float) -> void:
	_stamina = clampf(_stamina + amount, 0.0, stats.stamina_capacity())


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
	_lifecycle_bus.start_serving()
	_start_swing(model.get_stroke_clip(stroke), 1.0)


func _spawn_serve_ball() -> void:
	var serve_ball: Ball = ball_scene.instantiate()
	serve_ball.initial_position = position + model.toss_point
	serve_ball.initial_velocity = Vector3(0, 5, 0)
	get_parent().add_child(serve_ball)
	ball_spawned.emit(serve_ball)


## Play sound for given stroke: a slice sound, a grunt or a flat hit.
func play_stroke_sound(stroke: Stroke) -> void:
	var grunts: Array = player_data.sounds.grunt_flat
	if stroke.stroke_type == Stroke.StrokeType.BACKHAND_SLICE or stroke.is_drop():
		audio_stream_player.stream = stroke_sounds_slice.pick_random()
	elif not grunts.is_empty() and randf() < player_data.sounds.grunt_frequency:
		audio_stream_player.stream = grunts.pick_random()
	else:
		audio_stream_player.stream = stroke_sounds_flat.pick_random()
	audio_stream_player.play()


## Set the active ball for this player
func set_active_ball(b: Ball) -> void:
	ball = b
	controller.ball_changed(b)


## Shows the aim and ideal position markers the controller reports.
func _update_controller_ui() -> void:
	var ideal_position: Variant = controller.get_ideal_position()
	ideal_position_marker.visible = ideal_position != null
	if ideal_position != null:
		ideal_position_marker.global_position = ideal_position
		var offset: Vector3 = ideal_position - global_position
		offset.y = 0.0
		ideal_position_marker.set_quality(positioning_quality(offset.length()))

	var aim_position: Variant = controller.get_aim_marker_position()
	ball_aim_marker.visible = aim_position != null
	if aim_position != null:
		ball_aim_marker.global_position = aim_position
		ball_aim_marker.set_radius(controller.get_aim_marker_radius())
		ball_aim_marker.set_highlighted(controller.is_aim_marker_highlighted())


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
	model.set_body_yaw(animation_snapshot["body_yaw"])
	model.animator.apply_snapshot(animation_snapshot)


func set_replay_mode(enabled: bool) -> void:
	_is_replay_mode = enabled


func set_replay_animation_paused(paused: bool) -> void:
	model.animator.active = not paused


func get_replay_animation_snapshot() -> Dictionary:
	var snapshot: Dictionary = model.animator.get_snapshot()
	snapshot["body_yaw"] = model.body_yaw
	return snapshot


func _on_lifecycle_phase_changed(current_phase: MatchLifecycleBus.Phase) -> void:
	controller.on_lifecycle_phase_changed(current_phase)


## Called by the MatchManager after a point concludes to update mental state.
func on_point_result(won: bool) -> void:
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
	(
		_feedback_tween
		. tween_property(
			_shot_feedback_label, "position:y", SHOT_FEEDBACK_HEIGHT + 0.8, SHOT_FEEDBACK_TIME
		)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_CUBIC)
	)
	(
		_feedback_tween
		. tween_property(_shot_feedback_label, "modulate:a", 0.0, SHOT_FEEDBACK_TIME * 0.5)
		. set_delay(SHOT_FEEDBACK_TIME * 0.5)
	)
	_feedback_tween.chain().tween_callback(_shot_feedback_label.hide)


## Whether the next shot of this player is the return of a serve.
func is_returning_serve() -> bool:
	return session.is_return_of_serve(self)


func get_lifecycle_bus() -> MatchLifecycleBus:
	return _lifecycle_bus


func get_current_state() -> PlayerStateMachine.State:
	return _state_machine.get_state()


## Current movement target, null while there is none.
func get_movement_target() -> Variant:
	return _movement.get_target()
