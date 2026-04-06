## Human player input handler for keyboard/mouse/gamepad controls
## Manages movement, aiming, and stroke execution
class_name HumanController
extends Controller

const MATCH_LIFECYCLE_BUS_SCRIPT: Script = preload("res://scripts/core/match_lifecycle_bus.gd")

signal pace_changed(pace: float)

## Static counter to assign gamepad indices to multiple players
static var _next_gamepad_index: int = 0

## Static counter to track how many controllers are using gamepads
static var _gamepad_controller_count: int = 0

## This controller's assigned gamepad index
var _assigned_gamepad_index: int = -1

## Input device instance (keyboard, mouse, or gamepad)
var _input_device: InputDevice

## Input state flags
var _stroke_mode_active: bool = false

## Stroke tracking
var _aiming_at: Vector3 = Vector3.ZERO
var _serve_controls: bool = false

## Pending stroke to execute (queued by controller, executed by player)
var _pending_stroke: Stroke = null

## Current stroke state for UI updates
var _is_stroke_active: bool = false
var _current_pace: float = 0.0

## Stored trajectory step from when stroke started
var _stroke_trajectory_step: TrajectoryStep = null


func _ready() -> void:
	super()  # Call base class initialization

	if not player.ball_aim_marker:
		push_error("HumanInput: ball_aim_marker not assigned in editor")
		return

	# Initialize the appropriate input device
	_initialize_input_device()

	await get_tree().create_timer(GameConstants.INPUT_STARTUP_DELAY).timeout
	player.ball_hit.connect(_on_player_ball_hit)
	_aiming_at = _get_default_aim()


## Update controller state - called by Player each frame
func update(delta: float) -> void:
	if not _input_device:
		return
		
	if _stroke_mode_active:
		# Calculate world-space aiming position BEFORE handling stroke input
		# (stroke_completed signal needs current _aiming_at value)
		var raw_aim_input: Vector3 = _input_device.get_aim_input()
		var forward: Vector3 = -player.global_basis.z.normalized()
		var right: Vector3 = player.global_basis.x.normalized()

		# Apply sensitivity to input, then coverage for max range
		var sensitive_input: Vector3 = 5 * raw_aim_input * delta
		var aim_offset: Vector3 = (
			right * sensitive_input.x +
			forward * sensitive_input.z
		)
		_aiming_at += aim_offset

	# Now handle stroke input (may emit stroke_completed which uses _aiming_at)
	_is_stroke_active = _input_device.handle_stroke_input()

	# Store pace for player to query
	_current_pace = _input_device.get_stroke_pace()

	# Emit pace signal for any listeners
	if _is_stroke_active and _current_pace > 0.0:
		pace_changed.emit(_current_pace)
		Loggie.msg("Aiming position: ", _aiming_at).debug()


## Initializes the appropriate input device based on available hardware
func _initialize_input_device() -> void:
	var connected_joypads: Array = Input.get_connected_joypads()

	# Check if gamepad is available for this player
	if connected_joypads.size() > _next_gamepad_index:
		# Assign this controller the next available gamepad
		_assigned_gamepad_index = connected_joypads[_next_gamepad_index]
		_next_gamepad_index += 1
		_gamepad_controller_count += 1

		_input_device = GamepadInput.new()
		add_child(_input_device)
		# Initialize the gamepad with the assigned device index
		_input_device.initialize(_assigned_gamepad_index)
	# Default to keyboard+mouse if no gamepad available
	else:
		_input_device = KeyboardInput.new()
		add_child(_input_device)
		_input_device.initialize(0)

	# Connect stroke signals
	_input_device.stroke_started.connect(_on_stroke_started)
	_input_device.stroke_updating.connect(_on_stroke_updating)
	_input_device.stroke_completed.connect(_on_stroke_completed)

	# Update mouse capture mode based on input devices
	_update_mouse_capture_mode()

## Handles stroke start - updates default aim position and begins player positioning
func _on_stroke_started() -> void:
	_stroke_mode_active = true

func _on_stroke_updating(pace: float, stroke_type: InputDevice.StrokeInputType) -> void:
	if not player.ball:
		return

	# Only create/update preliminary stroke once ball is flying towards player
	if is_flying_towards(player, player.ball):
		_stroke_trajectory_step = get_closest_trajectory_step(player)

		# Create/recreate preliminary stroke with updated trajectory and pace
		if _stroke_trajectory_step:
			var updated_stroke: Stroke = _construct_stroke_from_input(
				_stroke_trajectory_step,
				_aiming_at,
				pace,
				stroke_type
			)
			if updated_stroke:
				_pending_stroke = updated_stroke


## Handles stroke completion
func _on_stroke_completed(pace: float, stroke_type: InputDevice.StrokeInputType) -> void:
	if _serve_controls:
		_do_serve(pace)
		_serve_controls = false
		_input_device.set_serve_mode(false)
	elif _stroke_trajectory_step and _pending_stroke:
		if player.global_position.distance_to(_stroke_trajectory_step.point) < 3:
			adjust_player_position_to_stroke(player, _stroke_trajectory_step, _pending_stroke)
	else:
		Loggie.msg(
			"HumanController._on_stroke_completed: missing trajectory/stroke; skipping position adjustment",
			" pace=", pace,
			" type=", stroke_type
		).debug()

## Prepares a serve stroke (to be executed by player)
func _do_serve(pace: float) -> void:
	_pending_stroke = _build_serve_stroke(_aiming_at, pace)

	_stroke_mode_active = true


## Constructs a stroke from player input, determining stroke type based on ball position
func _construct_stroke_from_input(
	closest_step: TrajectoryStep,
	aim_position: Vector3,
	pace: float,
	stroke_input_type: InputDevice.StrokeInputType
) -> Stroke:
	Loggie.msg("_construct_stroke_from_input", aim_position, pace, stroke_input_type).info()
	if not closest_step:
		Loggie.msg("_construct_stroke_from_input: closest_step is null")
		return null

	var to_ball_vector: Vector3 = closest_step.point - player.position
	var dot_product: float = to_ball_vector.dot(player.basis.x)
	var is_forehand: bool = dot_product > 0.0

	var stroke: Stroke = _build_rally_stroke(is_forehand, stroke_input_type, aim_position, pace)

	stroke.step = closest_step
	return stroke


func _build_serve_stroke(aim_position: Vector3, pace: float) -> Stroke:
	var stroke: Stroke = Stroke.new()
	stroke.stroke_type = Stroke.StrokeType.SERVE
	stroke.stroke_power = GameConstants.AI_SERVE_PACE + pace
	stroke.stroke_spin = GameConstants.AI_SERVE_SPIN
	stroke.stroke_target = aim_position
	return stroke


func _build_rally_stroke(
	is_forehand: bool,
	stroke_input_type: InputDevice.StrokeInputType,
	aim_position: Vector3,
	pace: float
) -> Stroke:
	var stroke: Stroke = Stroke.new()
	stroke.stroke_target = aim_position

	if is_forehand:
		stroke.stroke_type = Stroke.StrokeType.FOREHAND
		stroke.stroke_power = GameConstants.AI_FOREHAND_PACE + pace
		stroke.stroke_spin = GameConstants.AI_FOREHAND_SPIN
		return stroke

	match stroke_input_type:
		InputDevice.StrokeInputType.SLICE:
			stroke.stroke_type = Stroke.StrokeType.BACKHAND_SLICE
			stroke.stroke_power = GameConstants.AI_BACKHAND_SLICE_PACE + pace
			stroke.stroke_spin = GameConstants.AI_BACKHAND_SLICE_SPIN
		InputDevice.StrokeInputType.DROP_SHOT:
			stroke.stroke_type = Stroke.StrokeType.BACKHAND_DROP_SHOT
			stroke.stroke_power = GameConstants.AI_DROP_SHOT_PACE + pace
			stroke.stroke_spin = GameConstants.AI_DROP_SHOT_SPIN
		_:
			stroke.stroke_type = Stroke.StrokeType.BACKHAND
			stroke.stroke_power = GameConstants.AI_BACKHAND_PACE + pace
			stroke.stroke_spin = GameConstants.AI_BACKHAND_SPIN

	return stroke


## Called when player successfully hits the ball
func _on_player_ball_hit() -> void:
	_reset_transient_input_state()
	_aiming_at = _get_default_aim()
	_vibrate_joypad(0.8, 0.1)  # Strong brief vibration on ball contact


func request_serve() -> void:
	_serve_controls = true
	_aiming_at = _get_default_aim()
	_input_device.set_serve_mode(true)


func on_lifecycle_phase_changed(_previous_phase: int, current_phase: int) -> void:
	match current_phase:
		MATCH_LIFECYCLE_BUS_SCRIPT.Phase.RALLY:
			_serve_controls = false
			if _input_device:
				_input_device.set_serve_mode(false)
		MATCH_LIFECYCLE_BUS_SCRIPT.Phase.POINT_ENDED, MATCH_LIFECYCLE_BUS_SCRIPT.Phase.IDLE:
			_reset_transient_input_state()
			_serve_controls = false
			if _input_device:
				_input_device.set_serve_mode(false)
			_aiming_at = _get_default_aim()


func _reset_transient_input_state() -> void:
	_stroke_mode_active = false
	_pending_stroke = null
	_stroke_trajectory_step = null
	_current_pace = 0.0
	_is_stroke_active = false


## Get movement direction from input device
func get_move_direction() -> Vector3:
	if not _input_device:
		return Vector3.ZERO

	if _stroke_mode_active:
		return player.compute_move_dir()
	else:
		# Get raw input from device
		var raw_input: Vector3 = _input_device.get_movement_input(
			player.global_basis, player.position
		)

		if raw_input == Vector3.ZERO:
			return player.compute_move_dir()

		# Apply player basis to convert raw input to world direction
		var forward: Vector3 = -player.global_basis.z.normalized()
		var right: Vector3 = player.global_basis.x.normalized()
		var direction: Vector3 = (
			(forward * raw_input.z + right * raw_input.x).normalized()
		)

		return direction


## Get pending stroke to execute
func get_stroke() -> Stroke:
	return _pending_stroke


## Get current aiming position for UI updates
func get_aiming_position() -> Vector3:
	return _aiming_at


## Get current stroke pace for UI updates
func get_current_pace() -> float:
	return _current_pace


## Check if stroke is currently active
func is_stroke_active() -> bool:
	return _is_stroke_active


## Check if in serve mode
func is_serving() -> bool:
	return _serve_controls


## Get aim marker position for UI - overrides base class
func get_aim_marker_position() -> Variant:
	return _aiming_at


## Get aim marker visibility state - overrides base class
func should_show_aim_marker() -> bool:
	# Show marker when stroke is active with pace OR when in serve mode
	return _stroke_mode_active or _serve_controls


## Get aim marker scale for UI - overrides base class
func get_aim_marker_scale() -> Vector3:
	# Scale based on pace when active, otherwise normal size
	return Vector3.ONE * (1.0 + _current_pace * 0.5)






## Update mouse capture mode - only capture if both players use gamepads
static func _update_mouse_capture_mode() -> void:
	# Only capture mouse if 2 gamepads are being used (local multiplayer with 2 gamepads)
	if _gamepad_controller_count >= 2:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Reset static counters (call this when starting a new match)
static func reset_input_assignments() -> void:
	_next_gamepad_index = 0
	_gamepad_controller_count = 0


## Gets default aiming position based on context (serve vs rally)
func _get_default_aim() -> Vector3:
	var default_aim: Vector3 = Vector3(
		0.0, 0.0, -sign(player.position.z) * GameConstants.AIM_FRONT_COURT
	)

	if _serve_controls:
		default_aim = Vector3(
			-sign(player.position.x) * GameConstants.AIM_BACK_COURT,
			0.0,
			-sign(player.position.z) * GameConstants.AIM_SERVE
		)

	return default_aim



## Vibrates the joypad with specified strength and duration
func _vibrate_joypad(strength: float, duration: float) -> void:
	strength = clamp(strength, 0.0, 1.0)

	# Only vibrate if this controller has an assigned gamepad
	if _assigned_gamepad_index < 0:
		return  # No gamepad assigned to this controller

	# Strong vibration (left motor) and weak vibration (right motor)
	Input.start_joy_vibration(_assigned_gamepad_index, strength * 0.8, strength * 0.5, duration)
