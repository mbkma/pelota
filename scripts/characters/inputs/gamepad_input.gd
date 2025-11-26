## Gamepad input implementation
## Uses analog stick for movement initially, switches to aiming after stroke button is pressed
class_name GamepadInput
extends InputDevice

var _input_pace: float = 0.0
var _current_stroke_type: String = "topspin"
var _aiming_at: Vector3 = Vector3.ZERO
var _is_in_aiming_mode: bool = false
var _serve_mode: bool = false
var _gamepad_index: int = 0

## Default aim position (set by parent controller)
var default_aim_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	if Input.get_connected_joypads().size() > 0:
		_gamepad_index = Input.get_connected_joypads()[0]


func get_movement_input(camera_basis: Basis, player_position: Vector3) -> Vector3:
	# Don't move while aiming with stroke button or during serve
	if _is_in_aiming_mode or _serve_mode:
		return Vector3.ZERO

	var raw_input := _get_gamepad_input()

	var forward: Vector3 = -camera_basis.z.normalized()
	var right: Vector3 = camera_basis.x.normalized()

	# Invert left/right for back player to match their reversed camera perspective
	var lr_multiplier: float = sign(player_position.z)
	var direction: Vector3 = (
		(forward * raw_input.y + right * raw_input.x * lr_multiplier).normalized()
	)

	return direction


func get_aiming_input() -> Vector2:
	return Vector2.ZERO  # Not used for gamepad


func handle_stroke_input() -> bool:
	var is_any_action_pressed: bool = (
		Input.is_action_pressed("strike") or
		Input.is_action_pressed("slice") or
		Input.is_action_pressed("drop_shot")
	)

	var is_any_action_just_pressed: bool = (
		Input.is_action_just_pressed("strike") or
		Input.is_action_just_pressed("slice") or
		Input.is_action_just_pressed("drop_shot")
	)

	var is_any_action_just_released: bool = (
		Input.is_action_just_released("strike") or
		Input.is_action_just_released("slice") or
		Input.is_action_just_released("drop_shot")
	)

	# During serve, allow aiming before stroke button is pressed
	if _serve_mode and not is_any_action_pressed:
		_aiming_at = _calculate_aim_position()

	# Initialize stroke when button is first pressed
	if is_any_action_just_pressed:
		_input_pace = 0.0
		_is_in_aiming_mode = true
		_aiming_at = default_aim_position
		stroke_started.emit()

	# Continuously update aim and pace while button is held
	if is_any_action_pressed:
		_input_pace += GameConstants.PACE_INCREMENT_RATE
		_input_pace = clamp(_input_pace, 0.0, 1.0)
		# Use right analog stick for aiming
		_aiming_at = _calculate_aim_position()
		stroke_updating.emit(_input_pace)

	# Complete stroke when button is released
	if is_any_action_just_released:
		# Determine which stroke type was used
		_current_stroke_type = "topspin"
		if Input.is_action_just_released("slice"):
			_current_stroke_type = "slice"
		elif Input.is_action_just_released("drop_shot"):
			_current_stroke_type = "drop_shot"

		_is_in_aiming_mode = false
		stroke_completed.emit(_input_pace, _current_stroke_type)
		return true

	return is_any_action_pressed


func get_stroke_pace() -> float:
	return _input_pace


func get_stroke_type() -> String:
	return _current_stroke_type


func get_aiming_position() -> Vector3:
	return _aiming_at


func clear_stroke_input() -> void:
	_input_pace = 0.0
	_is_in_aiming_mode = false


func set_serve_mode(enabled: bool) -> void:
	_serve_mode = enabled


func _get_gamepad_input() -> Vector2:
	# Use same action system as movement for consistency
	var x_input: float = (
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	)
	var y_input: float = (
		Input.get_action_strength("move_front") - Input.get_action_strength("move_back")
	)

	return Vector2(x_input, y_input)


func _calculate_aim_position() -> Vector3:
	var aim_input: Vector2 = _get_gamepad_input()
	var player_side: float = sign(default_aim_position.z)

	var aim_sensitivity: float = GameConstants.MOUSE_SENSITIVITY / 100.0  # Scale for analog stick sensitivity

	var aim_position: Vector3 = default_aim_position
	aim_position.x += -player_side * aim_input.x * aim_sensitivity
	aim_position.z += player_side * aim_input.y * aim_sensitivity

	return aim_position
