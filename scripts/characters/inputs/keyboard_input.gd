## Keyboard-only input implementation
## Both movement and aiming via keyboard
class_name KeyboardInput
extends InputDevice

var _input_pace: float = 0.0
var _current_stroke_type: String = "topspin"
var _aiming_at: Vector3 = Vector3.ZERO
var _serve_mode: bool = false

## Movement key states
var _move_left_pressed: bool = false
var _move_right_pressed: bool = false
var _move_front_pressed: bool = false
var _move_back_pressed: bool = false

## Button state tracking (keyboard-only)
var _strike_pressed: bool = false
var _slice_pressed: bool = false
var _drop_shot_pressed: bool = false

var _strike_just_pressed: bool = false
var _slice_just_pressed: bool = false
var _drop_shot_just_pressed: bool = false

var _strike_just_released: bool = false
var _slice_just_released: bool = false
var _drop_shot_just_released: bool = false


func initialize(_index: int) -> void:
	set_process_input(true)
	set_process(true)


func _input(event: InputEvent) -> void:
	# Only process keyboard events, ignore all gamepad events
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return

	# Process keyboard button events
	if event is InputEventKey:
		_process_keyboard_event(event)


func _process(_delta: float) -> void:
	# Reset just_pressed and just_released flags each frame
	# They get set in _input() when events occur
	pass


func get_movement_input(_player_basis: Basis, _player_position: Vector3) -> Vector3:
	# No movement during serve
	if _serve_mode:
		return Vector3.ZERO

	# Return raw input - controller will apply player basis
	return _get_keyboard_movement()


func handle_stroke_input() -> bool:
	var is_any_action_pressed: bool = (
		_strike_pressed or _slice_pressed or _drop_shot_pressed
	)

	var is_any_action_just_pressed: bool = (
		_strike_just_pressed or _slice_just_pressed or _drop_shot_just_pressed
	)

	var is_any_action_just_released: bool = (
		_strike_just_released or _slice_just_released or _drop_shot_just_released
	)

	# Capture which button was pressed/released before resetting (for stroke type detection)
	var slice_just_pressed: bool = _slice_just_pressed
	var drop_shot_just_pressed: bool = _drop_shot_just_pressed

	# Reset just_pressed and just_released flags after reading
	_strike_just_pressed = false
	_slice_just_pressed = false
	_drop_shot_just_pressed = false
	_strike_just_released = false
	_slice_just_released = false
	_drop_shot_just_released = false

	# During serve, allow aiming before stroke button is pressed (but don't skip if button was just released!)
	if _serve_mode and not is_any_action_pressed and not is_any_action_just_released:
		return false  # Aiming will be calculated by controller using get_aim_input()

	# Initialize stroke when button is first pressed
	if is_any_action_just_pressed:
		_input_pace = 0.0

		# Determine stroke type based on which button was pressed
		_current_stroke_type = "topspin"
		if slice_just_pressed:
			_current_stroke_type = "slice"
		elif drop_shot_just_pressed:
			_current_stroke_type = "drop_shot"

		stroke_started.emit()

	# Continuously update aim and pace while button is held
	if is_any_action_pressed:
		_input_pace += GameConstants.PACE_INCREMENT_RATE
		_input_pace = clamp(_input_pace, 0.0, 5.0)
		stroke_updating.emit(_input_pace, _current_stroke_type)

	# Complete stroke when button is released
	if is_any_action_just_released:
		stroke_completed.emit(_input_pace, _current_stroke_type)
		return true

	return is_any_action_pressed


func get_stroke_pace() -> float:
	return _input_pace


func get_stroke_type() -> String:
	return _current_stroke_type


func get_aiming_position() -> Vector3:
	return _aiming_at

## Get raw aim input (relative to player, not world coordinates)
func get_aim_input() -> Vector3:
	var aim_input: Vector3 = _get_keyboard_movement()

	# Return raw input offset - controller will apply player basis
	return Vector3(aim_input.x, 0.0, aim_input.z)

func clear_stroke_input() -> void:
	_input_pace = 0.0


func set_serve_mode(enabled: bool) -> void:
	_serve_mode = enabled


## Process keyboard events only, tracking button states
func _process_keyboard_event(event: InputEventKey) -> void:
	var is_pressed: bool = event.is_pressed()
	var keycode: Key = event.keycode

	# Movement keys - WASD
	if keycode == KEY_A:
		_move_left_pressed = is_pressed
	elif keycode == KEY_D:
		_move_right_pressed = is_pressed
	elif keycode == KEY_W:
		_move_front_pressed = is_pressed
	elif keycode == KEY_S:
		_move_back_pressed = is_pressed

	# Movement keys - Arrow keys
	elif keycode == KEY_LEFT:
		_move_left_pressed = is_pressed
	elif keycode == KEY_RIGHT:
		_move_right_pressed = is_pressed
	elif keycode == KEY_UP:
		_move_front_pressed = is_pressed
	elif keycode == KEY_DOWN:
		_move_back_pressed = is_pressed

	# Stroke keys - Space for topspin, Shift for slice, Ctrl for drop shot
	elif keycode == KEY_SPACE:
		_strike_just_pressed = is_pressed and not _strike_pressed
		_strike_just_released = not is_pressed and _strike_pressed
		_strike_pressed = is_pressed

	elif keycode == KEY_SHIFT:
		_slice_just_pressed = is_pressed and not _slice_pressed
		_slice_just_released = not is_pressed and _slice_pressed
		_slice_pressed = is_pressed

	elif keycode == KEY_CTRL:
		_drop_shot_just_pressed = is_pressed and not _drop_shot_pressed
		_drop_shot_just_released = not is_pressed and _drop_shot_pressed
		_drop_shot_pressed = is_pressed


## Get keyboard movement input (filters out gamepad input)
func _get_keyboard_movement() -> Vector3:
	var x_input: float = 0.0
	var z_input: float = 0.0

	if _move_right_pressed:
		x_input += 1.0
	if _move_left_pressed:
		x_input -= 1.0
	if _move_front_pressed:
		z_input += 1.0
	if _move_back_pressed:
		z_input -= 1.0

	return Vector3(x_input, 0.0, z_input)
