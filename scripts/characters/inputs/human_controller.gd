## Human player input handler for keyboard/mouse/gamepad controls
## Manages movement, aiming, and stroke execution
class_name HumanController
extends Controller

## Local signal for aiming position (parent class has aiming_at_position)
signal aiming_at_pos(position: Vector3)

## Static counter to assign gamepad indices to multiple players
static var _next_gamepad_index: int = 0

## Static counter to track how many controllers are using gamepads
static var _gamepad_controller_count: int = 0

## This controller's assigned gamepad index
var _assigned_gamepad_index: int = -1

## Input device instance (keyboard, mouse, or gamepad)
var _input_device: InputDevice

## Input state flags
var _move_input_blocked: bool = false
var _stroke_input_blocked: bool = true

## Aim control parameters
@export var aim_sensitivity: float = 1.0  ## How responsive aim is to input (0.1 = slow, 2.0 = fast)
@export var aim_coverage_horizontal: float = 5.0  ## Max horizontal aim range (left/right)
@export var aim_coverage_depth: float = 5.0  ## Max depth aim range (forward/back)

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
	if not validate_player():
		set_process(false)
		set_physics_process(false)
		return

	if not player.ball_aim_marker:
		push_error("HumanInput: ball_aim_marker not assigned in editor")
		set_process(false)
		return

	# Initialize the appropriate input device
	_initialize_input_device()

	await get_tree().create_timer(GameConstants.INPUT_STARTUP_DELAY).timeout
	_stroke_input_blocked = false
	player.ball_aim_marker.global_position = _get_default_aim()
	player.ball_aim_marker.visible = true
	player.ball_hit.connect(_on_player_ball_hit)


## Update controller state - called by Player each frame
func update() -> void:
	if not _input_device:
		return

	# Handle stroke input and update internal state
	if not _stroke_input_blocked:
		# Calculate world-space aiming position BEFORE handling stroke input
		# (stroke_completed signal needs current _aiming_at value)
		var raw_aim_input: Vector3 = _input_device.get_aim_input()
		var forward: Vector3 = player.global_basis.z.normalized()
		var right: Vector3 = player.global_basis.x.normalized()

		# Apply sensitivity to input, then coverage for max range
		var sensitive_input: Vector3 = raw_aim_input * aim_sensitivity
		var aim_offset: Vector3 = (
			right * sensitive_input.x * aim_coverage_horizontal +
			forward * sensitive_input.z * aim_coverage_depth
		)
		_aiming_at = _get_default_aim() + aim_offset

		# Now handle stroke input (may emit stroke_completed which uses _aiming_at)
		_is_stroke_active = _input_device.handle_stroke_input()

		# Store pace for player to query
		_current_pace = _input_device.get_stroke_pace()

		# Emit pace signal for any listeners
		if _is_stroke_active and _current_pace > 0.0:
			pace_changed.emit(_current_pace)
			Loggie.msg("Aiming position: ", _aiming_at).debug()


func request_serve() -> void:
	_serve_controls = true
	_input_device.default_aim_position = _get_default_aim()
	_input_device.set_serve_mode(true)


## Get movement direction from input device
func get_move_direction() -> Vector3:
	if not _input_device:
		return Vector3.ZERO

	if _move_input_blocked:
		# Block movement input during stroke animation, use path-based movement
		return player.compute_move_dir()
	else:
		# Get raw input from device
		var raw_input: Vector3 = _input_device.get_movement_input(
			player.global_basis, player.position
		)

		if raw_input == Vector3.ZERO:
			return Vector3.ZERO

		# Apply player basis to convert raw input to world direction
		var forward: Vector3 = player.global_basis.z.normalized()
		var right: Vector3 = player.global_basis.x.normalized()
		var direction: Vector3 = (
			(forward * raw_input.z + right * raw_input.x).normalized()
		)

		return direction


## Get pending stroke to execute
func get_stroke() -> Stroke:
	var stroke: Stroke = _pending_stroke
	_pending_stroke = null  # Clear after returning
	return stroke


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
	return (_is_stroke_active and _current_pace > 0.0) or _serve_controls


## Get aim marker scale for UI - overrides base class
func get_aim_marker_scale() -> Vector3:
	# Scale based on pace when active, otherwise normal size
	if _is_stroke_active and _current_pace > 0.0:
		return Vector3.ONE * (1.0 + _current_pace * 0.5)
	else:
		return Vector3.ONE


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

	# Set default aim position for the input device
	_input_device.default_aim_position = _get_default_aim()

	# Connect stroke signals
	_input_device.stroke_started.connect(_on_stroke_started)
	_input_device.stroke_completed.connect(_on_stroke_completed, CONNECT_ONE_SHOT)

	# Update mouse capture mode based on input devices
	_update_mouse_capture_mode()


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


## Handles stroke start - updates default aim position and begins player positioning
func _on_stroke_started() -> void:
	var default_aim: Vector3 = _get_default_aim()
	_input_device.default_aim_position = default_aim

	# For rally strokes (not serves), start positioning the player immediately
	if not _serve_controls:
		_prepare_for_stroke()


## Prepares player positioning when stroke button is pressed
func _prepare_for_stroke() -> void:
	if not player.ball:
		return

	var closest_step: TrajectoryStep = get_closest_trajectory_step(player)
	if not closest_step:
		return

	var closest_ball_position: Vector3 = closest_step.point

	# Ensure ball is on same side of court as player
	if sign(closest_ball_position.z) != sign(player.position.z):
		return

	# Store for later use in _set_pending_stroke
	_stroke_trajectory_step = closest_step

	# Determine if it's forehand or backhand based on ball position
	var to_ball_vector: Vector3 = closest_step.point - player.position
	var dot_product: float = to_ball_vector.dot(player.basis.x)

	# Create a preliminary stroke just to determine positioning
	var preliminary_stroke: Stroke = Stroke.new()
	if dot_product > 0.0:
		preliminary_stroke.stroke_type = Stroke.StrokeType.FOREHAND
	else:
		preliminary_stroke.stroke_type = Stroke.StrokeType.BACKHAND

	# Start moving player to optimal position
	adjust_player_position_to_stroke(player, closest_step, preliminary_stroke)
	_move_input_blocked = true
	Loggie.msg("moving to ", closest_step.point).info()


## Handles stroke completion
func _on_stroke_completed(pace: float, stroke_type: String) -> void:
	if _serve_controls:
		_do_serve(_aiming_at, pace)
		_serve_controls = false
		_input_device.set_serve_mode(false)
	else:
		_set_pending_stroke(_aiming_at, pace, stroke_type)

	_input_device.clear_stroke_input()

	# Reconnect for next stroke since CONNECT_ONE_SHOT disconnects after firing
	_input_device.stroke_completed.connect(_on_stroke_completed, CONNECT_ONE_SHOT)


## Prepares a serve stroke (to be executed by player)
func _do_serve(aim_position: Vector3, pace: float) -> void:
	var stroke: Stroke = Stroke.new()
	stroke.stroke_type = Stroke.StrokeType.SERVE
	stroke.stroke_power = GameConstants.AI_SERVE_PACE + pace
	stroke.stroke_spin = GameConstants.AI_SERVE_SPIN
	stroke.stroke_target = aim_position

	_move_input_blocked = true
	_pending_stroke = stroke


## Prepares a rally stroke (to be executed by player)
func _set_pending_stroke(aim_position: Vector3, pace: float, stroke_name := "topspin") -> void:
	if not player.ball:
		Loggie.msg("HumanInput._set_pending_stroke: Player has no ball to stroke").info()
		return

	# Use stored trajectory step if available (from _prepare_for_stroke), otherwise calculate
	var closest_step: TrajectoryStep = _stroke_trajectory_step
	if not closest_step:
		closest_step = get_closest_trajectory_step(player)

	# Clear stored step
	_stroke_trajectory_step = null

	if not closest_step:
		Loggie.msg("HumanInput._set_pending_stroke: Could not find ball trajectory step").info()
		_move_input_blocked = false
		return

	var closest_ball_position: Vector3 = closest_step.point

	# Ensure ball is on same side of court as player
	if sign(closest_ball_position.z) != sign(player.position.z):
		Loggie.msg(
			"HumanInput._set_pending_stroke: Ball is on opposite side of court (player: ",
			player.position.z,
			", ball: ",
			closest_ball_position.z,
			")"
		)
		_move_input_blocked = false
		return

	var stroke: Stroke = _construct_stroke_from_input(closest_step, aim_position, pace, stroke_name)
	_move_input_blocked = true

	# Queue stroke to be executed by player (positioning already started in _prepare_for_stroke)
	_pending_stroke = stroke


## Constructs a stroke from player input, determining stroke type based on ball position
func _construct_stroke_from_input(
	closest_step: TrajectoryStep, aim_position: Vector3, pace: float, stroke_name: String
) -> Stroke:
	Loggie.msg("_construct_stroke_from_input", aim_position, pace, stroke_name).info()
	if not closest_step:
		Loggie.msg("_construct_stroke_from_input: closest_step is null")
		return Stroke.new()

	var stroke: Stroke = Stroke.new()
	var to_ball_vector: Vector3 = closest_step.point - player.position
	var dot_product: float = to_ball_vector.dot(player.basis.x)

	if dot_product > 0.0:
		# Forehand stroke
		stroke.stroke_type = Stroke.StrokeType.FOREHAND
		stroke.stroke_power = GameConstants.AI_FOREHAND_PACE + pace
		stroke.stroke_spin = GameConstants.AI_FOREHAND_SPIN
		stroke.stroke_target = aim_position
	else:
		# Backhand or slice stroke
		if stroke_name == "slice":
			stroke.stroke_type = Stroke.StrokeType.BACKHAND_SLICE
			stroke.stroke_power = GameConstants.AI_BACKHAND_SLICE_PACE + pace
			stroke.stroke_spin = GameConstants.AI_BACKHAND_SLICE_SPIN
			stroke.stroke_target = aim_position
		elif stroke_name == "drop_shot":
			stroke.stroke_type = Stroke.StrokeType.BACKHAND_DROP_SHOT
			stroke.stroke_power = GameConstants.AI_DROP_SHOT_PACE + pace
			stroke.stroke_spin = GameConstants.AI_DROP_SHOT_SPIN
			stroke.stroke_target = aim_position
		else:
			stroke.stroke_type = Stroke.StrokeType.BACKHAND
			stroke.stroke_power = GameConstants.AI_BACKHAND_PACE + pace
			stroke.stroke_spin = GameConstants.AI_BACKHAND_SPIN
			stroke.stroke_target = aim_position

	stroke.step = closest_step
	return stroke


## Called when player successfully hits the ball
func _on_player_ball_hit() -> void:
	_move_input_blocked = false
	_vibrate_joypad(0.8, 0.1)  # Strong brief vibration on ball contact


## Vibrates the joypad with specified strength and duration
func _vibrate_joypad(strength: float, duration: float) -> void:
	strength = clamp(strength, 0.0, 1.0)

	# Only vibrate if this controller has an assigned gamepad
	if _assigned_gamepad_index < 0:
		return  # No gamepad assigned to this controller

	# Strong vibration (left motor) and weak vibration (right motor)
	Input.start_joy_vibration(_assigned_gamepad_index, strength * 0.8, strength * 0.5, duration)
