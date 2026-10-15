## Keyboard, in one of two layouts picked in the input options (see Layout). WASD or the arrow
## keys give the direction in both.
class_name KeyboardInput
extends InputDevice

enum Layout {
	## WASD always moves the player, the mouse aims; left click topspin, right click slice,
	## Q or middle click drop shot.
	KEYBOARD_AND_MOUSE,
	## WASD moves, and during a shot picks the aim zone; J topspin, K slice, L drop shot.
	KEYBOARD_ONLY,
}

## Device id of the keyboard (joypad ids are >= 0).
const DEVICE_ID: int = -2

## Setting of the input options: the keyboard layout
const LAYOUT_SECTION: StringName = AppSettings.INPUT_SECTION
const LAYOUT_KEY: StringName = &"KeyboardLayout"
## Setting of the input options: the mouse sensitivity (a factor around 1)
const MOUSE_SENSITIVITY_KEY: StringName = &"MouseSensitivity"
## Mouse motion (px) that moves the aim from the middle to a line at sensitivity 1
const MOUSE_AIM_RANGE_PIXELS: float = 350.0

const RIGHT_KEYS: Array[Key] = [KEY_D, KEY_RIGHT]
const LEFT_KEYS: Array[Key] = [KEY_A, KEY_LEFT]
const FORWARD_KEYS: Array[Key] = [KEY_W, KEY_UP]
const BACK_KEYS: Array[Key] = [KEY_S, KEY_DOWN]
const ACCEPT_KEYS: Array[Key] = [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]

## Stroke keys and mouse buttons per layout
const MOUSE_LAYOUT_KEYS: Dictionary[Action, Key] = {
	Action.DROP_SHOT: KEY_Q,
}
const MOUSE_LAYOUT_BUTTONS: Dictionary[Action, MouseButton] = {
	Action.STRIKE: MOUSE_BUTTON_LEFT,
	Action.SLICE: MOUSE_BUTTON_RIGHT,
	Action.DROP_SHOT: MOUSE_BUTTON_MIDDLE,
}
const KEYBOARD_LAYOUT_KEYS: Dictionary[Action, Key] = {
	Action.STRIKE: KEY_J,
	Action.SLICE: KEY_K,
	Action.DROP_SHOT: KEY_L,
}

## Mouse motion (px, y down) since the previous poll
var _mouse_motion: Vector2 = Vector2.ZERO


## The layout picked in the input options.
static func get_layout() -> Layout:
	return PlayerConfig.get_config(LAYOUT_SECTION, LAYOUT_KEY, Layout.KEYBOARD_AND_MOUSE)


func get_device_id() -> int:
	return DEVICE_ID


func get_display_name() -> String:
	return "Keyboard & Mouse" if _uses_mouse() else "Keyboard"


func get_aim_mode() -> AimMode:
	return AimMode.POINTER if _uses_mouse() else AimMode.ZONES


func handle_input_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_motion += event.screen_relative


func _take_pointer_motion() -> Vector2:
	var motion: Vector2 = _mouse_motion
	_mouse_motion = Vector2.ZERO
	if not _uses_mouse():
		return Vector2.ZERO
	var sensitivity: float = PlayerConfig.get_config(LAYOUT_SECTION, MOUSE_SENSITIVITY_KEY, 1.0)
	# Screen y points down, the pointer motion up.
	return Vector2(motion.x, -motion.y) * sensitivity / MOUSE_AIM_RANGE_PIXELS


func _read_direction() -> Vector2:
	var direction := Vector2(
		float(_any_pressed(RIGHT_KEYS)) - float(_any_pressed(LEFT_KEYS)),
		float(_any_pressed(FORWARD_KEYS)) - float(_any_pressed(BACK_KEYS))
	)
	return direction.normalized()


func _is_action_held(action: Action) -> bool:
	if not _uses_mouse():
		return Input.is_physical_key_pressed(KEYBOARD_LAYOUT_KEYS[action])
	if action in MOUSE_LAYOUT_KEYS and Input.is_physical_key_pressed(MOUSE_LAYOUT_KEYS[action]):
		return true
	return Input.is_mouse_button_pressed(MOUSE_LAYOUT_BUTTONS[action])


func _is_accept_held() -> bool:
	return _any_pressed(ACCEPT_KEYS)


func _uses_mouse() -> bool:
	return get_layout() == Layout.KEYBOARD_AND_MOUSE


func _any_pressed(keys: Array[Key]) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false
