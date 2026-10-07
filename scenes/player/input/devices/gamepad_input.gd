## One gamepad: left stick or d-pad for direction, A topspin, X slice, Y drop shot.
## Only reads its own joypad, so several gamepads can control different players.
class_name GamepadInput
extends InputDevice

const ACTION_BUTTONS: Dictionary[Action, JoyButton] = {
	Action.STRIKE: JOY_BUTTON_A,
	Action.SLICE: JOY_BUTTON_X,
	Action.DROP_SHOT: JOY_BUTTON_Y,
}

var _joypad_id: int


func _init(joypad_id: int) -> void:
	super()
	_joypad_id = joypad_id


func get_device_id() -> int:
	return _joypad_id


func get_display_name() -> String:
	var joy_name: String = Input.get_joy_name(_joypad_id)
	if joy_name.is_empty():
		return "Gamepad %d" % (_joypad_id + 1)
	return joy_name


func vibrate(weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	Input.start_joy_vibration(_joypad_id, weak_magnitude, strong_magnitude, duration)


func _read_direction() -> Vector2:
	var dpad := Vector2(
		float(_is_button_pressed(JOY_BUTTON_DPAD_RIGHT)) - float(_is_button_pressed(JOY_BUTTON_DPAD_LEFT)),
		float(_is_button_pressed(JOY_BUTTON_DPAD_UP)) - float(_is_button_pressed(JOY_BUTTON_DPAD_DOWN))
	)
	if dpad != Vector2.ZERO:
		return dpad.normalized()

	# Stick y points down, the device direction points forward.
	var stick := Vector2(
		Input.get_joy_axis(_joypad_id, JOY_AXIS_LEFT_X),
		-Input.get_joy_axis(_joypad_id, JOY_AXIS_LEFT_Y)
	)
	return stick.limit_length(1.0)


func _is_action_held(action: Action) -> bool:
	return _is_button_pressed(ACTION_BUTTONS[action])


func _is_accept_held() -> bool:
	return _is_button_pressed(JOY_BUTTON_A)


func _is_button_pressed(button: JoyButton) -> bool:
	return Input.is_joy_button_pressed(_joypad_id, button)
