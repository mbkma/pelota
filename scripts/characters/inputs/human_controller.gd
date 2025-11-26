## Human player input handler for keyboard/mouse/gamepad controls
## Manages movement, aiming, and stroke execution
class_name HumanController
extends Controller

## Local signal for aiming position (parent class has aiming_at_position)
signal aiming_at_pos(position: Vector3)

## Input device instance (keyboard, mouse, or gamepad)
var _input_device: InputDevice

## Input state flags
var _move_input_blocked: bool = false
var _stroke_input_blocked: bool = true

## Stroke tracking
var _aiming_at: Vector3 = Vector3.ZERO
var _serve_controls: bool = false


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


func _process(_delta: float) -> void:
	if not _input_device:
		return

	# Handle stroke input
	if not _stroke_input_blocked:
		var is_stroke_active: bool = _input_device.handle_stroke_input()

		# Get the latest aiming position from the input device
		_aiming_at = _input_device.get_aiming_position()

		# Update UI while stroke is active or during serve (before button press)
		var pace: float = _input_device.get_stroke_pace()
		if is_stroke_active and pace > 0.0:
			pace_changed.emit(pace)
			Loggie.msg("[Aiming] Position: ", _aiming_at).debug()
			player.ball_aim_marker.global_position = _aiming_at
			player.ball_aim_marker.visible = true
			# Scale marker based on pace for visual feedback (1.0 - 1.5x size)
			player.ball_aim_marker.scale = Vector3.ONE * (1.0 + pace * 0.5)
		elif _serve_controls:
			# During serve, show aim marker even before pressing stroke button
			Loggie.msg("[Aiming] Position: ", _aiming_at).debug()
			player.ball_aim_marker.global_position = _aiming_at
			player.ball_aim_marker.visible = true
			player.ball_aim_marker.scale = Vector3.ONE


func request_serve() -> void:
	_serve_controls = true
	_input_device.default_aim_position = _get_default_aim()
	_input_device.set_serve_mode(true)


func _physics_process(_delta: float) -> void:
	if not _input_device:
		return

	if _move_input_blocked:
		# Block all movement during stroke animation
		#player.apply_movement(Vector3.ZERO, _delta)
		return
	else:
		var move_direction: Vector3 = _input_device.get_movement_input(
			player.camera.global_basis, player.position
		)
		player.apply_movement(move_direction, _delta)


## Initializes the appropriate input device based on available hardware
func _initialize_input_device() -> void:
	# Check if gamepad is connected
	if Input.get_connected_joypads().size() > 0:
		_input_device = GamepadInput.new()
	# Check if mouse is being used (default to keyboard+mouse if no gamepad)
	else:
		_input_device = KeyboardMouseInput.new()

	add_child(_input_device)

	# Set default aim position for the input device
	_input_device.default_aim_position = _get_default_aim()

	# Connect stroke signals
	_input_device.stroke_started.connect(_on_stroke_started)
	_input_device.stroke_completed.connect(_on_stroke_completed, CONNECT_ONE_SHOT)


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


## Handles stroke start - updates default aim position
func _on_stroke_started() -> void:
	var default_aim: Vector3 = _get_default_aim()
	_input_device.default_aim_position = default_aim


## Handles stroke completion
func _on_stroke_completed(pace: float, stroke_type: String) -> void:
	if _serve_controls:
		_do_serve(_aiming_at, pace)
		_serve_controls = false
		_input_device.set_serve_mode(false)
	else:
		_do_stroke(_aiming_at, pace, stroke_type)

	_input_device.clear_stroke_input()

	# Reconnect for next stroke since CONNECT_ONE_SHOT disconnects after firing
	_input_device.stroke_completed.connect(_on_stroke_completed, CONNECT_ONE_SHOT)


## Executes a serve stroke
func _do_serve(aim_position: Vector3, pace: float) -> void:
	var stroke: Stroke = Stroke.new()
	stroke.stroke_type = Stroke.StrokeType.SERVE
	stroke.stroke_power = GameConstants.AI_SERVE_PACE + pace
	stroke.stroke_spin = GameConstants.AI_SERVE_SPIN
	stroke.stroke_target = aim_position

	_move_input_blocked = true
	player.serve(stroke)


## Executes a rally stroke (forehand/backhand/slice)
func _do_stroke(aim_position: Vector3, pace: float, stroke_name := "topspin") -> void:
	if not player.ball:
		Loggie.msg("HumanInput._do_stroke: Player has no ball to stroke").info()
		return

	var closest_step: TrajectoryStep = get_closest_trajectory_step(player)
	if not closest_step:
		Loggie.msg("HumanInput._do_stroke: Could not find ball trajectory step").info()
		_move_input_blocked = false
		return

	var closest_ball_position: Vector3 = closest_step.point

	# Ensure ball is on same side of court as player
	if sign(closest_ball_position.z) != sign(player.position.z):
		Loggie.msg(
			"HumanInput._do_stroke: Ball is on opposite side of court (player: ",
			player.position.z,
			", ball: ",
			closest_ball_position.z,
			")"
		)
		_move_input_blocked = false
		return

	var stroke: Stroke = _construct_stroke_from_input(closest_step, aim_position, pace, stroke_name)
	_move_input_blocked = true

	player.queue_stroke(stroke)
	adjust_player_position_to_stroke(player, closest_step)

	_clear_stroke_input_ui()


## Clears stroke UI state after executing a stroke
func _clear_stroke_input_ui() -> void:
	player.ball_aim_marker.visible = false


## Constructs a stroke from player input, determining stroke type based on ball position
func _construct_stroke_from_input(
	closest_step: TrajectoryStep, aim_position: Vector3, pace: float, stroke_name: String
) -> Stroke:
	Loggie.msg("HumanInput._construct_stroke_from_input", aim_position, pace, stroke_name).info()
	if not closest_step:
		Loggie.msg("HumanInput._construct_stroke_from_input: closest_step is null")
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
			stroke.stroke_power = GameConstants.AI_BACKHAND_SLICE_PACE
			stroke.stroke_spin = GameConstants.AI_BACKHAND_SLICE_SPIN
			stroke.stroke_target = aim_position
		elif stroke_name == "drop_shot":
			stroke.stroke_type = Stroke.StrokeType.BACKHAND_DROP_SHOT
			stroke.stroke_power = GameConstants.AI_DROP_SHOT_PACE
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

	# Get the first connected joypad
	var joypad_id: int = 0
	if Input.get_connected_joypads().size() > 0:
		joypad_id = Input.get_connected_joypads()[0]
	else:
		return  # No joypad connected

	# Strong vibration (left motor) and weak vibration (right motor)
	Input.start_joy_vibration(joypad_id, strength * 0.8, strength * 0.5, duration)
