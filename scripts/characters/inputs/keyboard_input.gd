## Keyboard-only input implementation
## Both movement and aiming via keyboard
class_name KeyboardInput
extends InputDevice

var _input_pace: float = 0.0
var _current_stroke_type: String = "topspin"
var _aiming_at: Vector3 = Vector3.ZERO
var _serve_mode: bool = false

## Default aim position (set by parent controller)
var default_aim_position: Vector3 = Vector3.ZERO


func get_movement_input(camera_basis: Basis, player_position: Vector3) -> Vector3:
	# No movement during serve
	if _serve_mode:
		return Vector3.ZERO

	var raw_input: Vector3 = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_front") - Input.get_action_strength("move_back")
	)

	var forward: Vector3 = -camera_basis.z.normalized()
	var right: Vector3 = camera_basis.x.normalized()

	# Invert left/right for back player to match their reversed camera perspective
	var lr_multiplier: float = sign(player_position.z)
	var direction: Vector3 = (
		(forward * raw_input.z + right * raw_input.x * lr_multiplier).normalized()
	)

	return direction


func get_aiming_input() -> Vector2:
	return Vector2.ZERO  # Not used for keyboard-only


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
		return false

	# Initialize stroke when button is first pressed
	if is_any_action_just_pressed:
		_input_pace = 0.0
		_aiming_at = default_aim_position
		stroke_started.emit()

	# Continuously update aim and pace while button is held
	if is_any_action_pressed:
		_input_pace += GameConstants.PACE_INCREMENT_RATE
		_input_pace = clamp(_input_pace, 0.0, 1.0)
		# For keyboard, aiming uses WASD or arrow keys (same as movement)
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


func set_serve_mode(enabled: bool) -> void:
	_serve_mode = enabled


func _calculate_aim_position() -> Vector3:
	var aim_input: Vector3 = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_front") - Input.get_action_strength("move_back")
	)

	var player_side: float = sign(default_aim_position.z) if default_aim_position.z != 0 else 1.0
	var aim_sensitivity: float = GameConstants.MOUSE_SENSITIVITY / 100.0  # Scale down since keyboard is discrete

	var aim_position: Vector3 = default_aim_position
	aim_position.x += player_side * aim_input.x * aim_sensitivity
	aim_position.z += player_side * aim_input.z * aim_sensitivity

	return aim_position
