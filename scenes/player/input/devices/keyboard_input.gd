## Keyboard: WASD or arrow keys for direction, Space topspin, Shift slice, Ctrl drop shot.
class_name KeyboardInput
extends InputDevice

## Device id of the keyboard (joypad ids are >= 0).
const DEVICE_ID: int = -2

const RIGHT_KEYS: Array[Key] = [KEY_D, KEY_RIGHT]
const LEFT_KEYS: Array[Key] = [KEY_A, KEY_LEFT]
const FORWARD_KEYS: Array[Key] = [KEY_W, KEY_UP]
const BACK_KEYS: Array[Key] = [KEY_S, KEY_DOWN]

const ACTION_KEYS: Dictionary[Action, Key] = {
	Action.STRIKE: KEY_SPACE,
	Action.SLICE: KEY_SHIFT,
	Action.DROP_SHOT: KEY_CTRL,
}


func get_device_id() -> int:
	return DEVICE_ID


func get_display_name() -> String:
	return "Keyboard"


func _read_direction() -> Vector2:
	var direction := Vector2(
		float(_any_pressed(RIGHT_KEYS)) - float(_any_pressed(LEFT_KEYS)),
		float(_any_pressed(FORWARD_KEYS)) - float(_any_pressed(BACK_KEYS))
	)
	return direction.normalized()


func _is_action_held(action: Action) -> bool:
	return Input.is_physical_key_pressed(ACTION_KEYS[action])


func _any_pressed(keys: Array[Key]) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false
