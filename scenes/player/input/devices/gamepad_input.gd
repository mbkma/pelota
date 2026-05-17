## Gamepad input implementation
## Uses analog stick for movement initially, switches to aiming after stroke button is pressed
class_name GamepadInput
extends InputDevice

var _input_pace: float = 0.0
var _current_stroke_type: StrokeInputType = StrokeInputType.TOPSPIN
var _is_in_aiming_mode: bool = false
var _serve_mode: bool = false
var _gamepad_index: int = -1
var _ignore_movement_until_neutral: bool = false

## Deadzone for stick neutral detection (0.2 is 20% of full range)
const STICK_DEADZONE: float = 0.2

## Button state tracking (per-device)
var _button_b_pressed: bool = false
var _button_x_pressed: bool = false
var _button_y_pressed: bool = false

var _button_b_just_pressed: bool = false
var _button_x_just_pressed: bool = false
var _button_y_just_pressed: bool = false

var _button_b_just_released: bool = false
var _button_x_just_released: bool = false
var _button_y_just_released: bool = false


## Initialize with a specific gamepad device index
func initialize(device_index: int) -> void:
	_gamepad_index = device_index
	set_process(true)


func _process(_delta: float) -> void:
	_update_button_states()


func get_movement_input(_player_basis: Basis, _player_position: Vector3) -> Vector3:
	# Don't move while aiming with stroke button or during serve
	if _is_in_aiming_mode or _serve_mode:
		return Vector3.ZERO

	var raw_input := _get_gamepad_input()

	# Check if we should ignore movement until stick returns to neutral
	if _ignore_movement_until_neutral:
		# Check if stick is near neutral position
		if raw_input.length() < STICK_DEADZONE:
			# Stick is neutral, allow movement again
			_ignore_movement_until_neutral = false
		else:
			# Still holding stick, ignore movement
			return Vector3.ZERO

	# Apply deadzone to prevent stick drift
	if raw_input.length() < STICK_DEADZONE:
		return Vector3.ZERO

	# Return raw input - controller will apply player basis
	return Vector3(raw_input.x, 0.0, raw_input.y)



func handle_stroke_input() -> bool:
	# Check if any stroke button is pressed (device-specific)
	var is_any_action_pressed: bool = (
		_button_b_pressed or _button_x_pressed or _button_y_pressed
	)

	var is_any_action_just_pressed: bool = (
		_button_b_just_pressed or _button_x_just_pressed or _button_y_just_pressed
	)

	var is_any_action_just_released: bool = (
		_button_b_just_released or _button_x_just_released or _button_y_just_released
	)

	# During serve, allow aiming before stroke button is pressed
	if _serve_mode and not is_any_action_pressed:
		pass  # Aiming will be calculated by controller using get_aim_input()

	# Initialize stroke when button is first pressed
	if is_any_action_just_pressed:
		_input_pace = 0.0
		_is_in_aiming_mode = true

		# Determine stroke type based on which button was pressed
		_current_stroke_type = StrokeInputType.TOPSPIN
		if _button_x_just_pressed:
			_current_stroke_type = StrokeInputType.SLICE
		elif _button_y_just_pressed:
			_current_stroke_type = StrokeInputType.DROP_SHOT

		emit_stroke_started()

	# Continuously update aim and pace while button is held
	if is_any_action_pressed:
		_input_pace += GameConstants.PACE_INCREMENT_RATE
		_input_pace = clamp(_input_pace, 0.0, 5.0)
		emit_stroke_updating(_input_pace, _current_stroke_type)

	# Complete stroke when button is released
	if is_any_action_just_released:
		_is_in_aiming_mode = false
		# Ignore movement input until stick returns to neutral
		_ignore_movement_until_neutral = true
		emit_stroke_completed(_input_pace, _current_stroke_type)
		return true

	return is_any_action_pressed


func get_stroke_pace() -> float:
	return _input_pace


func get_stroke_type() -> StrokeInputType:
	return _current_stroke_type

## Get raw aim input (relative to player, not world coordinates)
func get_aim_input() -> Vector3:
	var aim_input: Vector2 = _get_gamepad_input()

	# Return raw input offset - controller will apply player basis
	return Vector3(aim_input.x , 0.0, aim_input.y)


func clear_stroke_input() -> void:
	_input_pace = 0.0
	_is_in_aiming_mode = false
	_ignore_movement_until_neutral = false


func set_serve_mode(enabled: bool) -> void:
	_serve_mode = enabled


## Update button states for this specific gamepad device
func _update_button_states() -> void:
	if _gamepad_index < 0:
		return

	# Get current button states from THIS gamepad only
	var b_now: bool = Input.is_joy_button_pressed(_gamepad_index, JOY_BUTTON_B)
	var x_now: bool = Input.is_joy_button_pressed(_gamepad_index, JOY_BUTTON_X)
	var y_now: bool = Input.is_joy_button_pressed(_gamepad_index, JOY_BUTTON_Y)

	# Detect just_pressed (was false, now true)
	_button_b_just_pressed = b_now and not _button_b_pressed
	_button_x_just_pressed = x_now and not _button_x_pressed
	_button_y_just_pressed = y_now and not _button_y_pressed

	# Detect just_released (was true, now false)
	_button_b_just_released = not b_now and _button_b_pressed
	_button_x_just_released = not x_now and _button_x_pressed
	_button_y_just_released = not y_now and _button_y_pressed

	# Update current state
	_button_b_pressed = b_now
	_button_x_pressed = x_now
	_button_y_pressed = y_now


## Get gamepad analog stick input from THIS gamepad only
func _get_gamepad_input() -> Vector2:
	if _gamepad_index < 0:
		return Vector2.ZERO

	# Use left stick axes from THIS gamepad only
	var x_input: float = Input.get_joy_axis(_gamepad_index, JOY_AXIS_LEFT_X)
	var y_input: float = Input.get_joy_axis(_gamepad_index, JOY_AXIS_LEFT_Y)

	return Vector2(x_input, y_input)
