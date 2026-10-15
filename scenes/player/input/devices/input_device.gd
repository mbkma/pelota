## A physical input device (the keyboard, with or without the mouse, or one gamepad).
## Used by HumanController in a match and by the player select menu to assign devices to players.
## Pass it the input events (handle_input_event), call poll() once per frame, then query the
## direction, the pointer motion and the stroke actions.
@abstract class_name InputDevice
extends RefCounted

enum Action {
	STRIKE,
	SLICE,
	DROP_SHOT,
}

## How the device aims a shot or serve (see HumanController).
enum AimMode {
	## The direction aims; a push sets where the aim goes, kept while a stick springs back.
	STICK,
	## A pointer (the mouse) moves the aim; the direction keeps moving the player.
	POINTER,
	## The direction held picks one of nine zones: left, middle or right, short, middle or deep.
	ZONES,
}

## Device id meaning "no device": the player is AI controlled.
const NO_DEVICE_ID: int = -1

## Direction lengths below this are treated as neutral.
const DEADZONE: float = 0.2

var _held: Array[bool] = []
var _previously_held: Array[bool] = []
var _accept_held: bool = false
var _accept_previously_held: bool = false
## Pointer motion of this frame (see get_pointer_motion)
var _pointer_motion: Vector2 = Vector2.ZERO


func _init() -> void:
	_held.resize(Action.size())
	_previously_held.resize(Action.size())


## Creates the device for a device id (KeyboardInput.DEVICE_ID or a joypad id).
static func create(device_id: int) -> InputDevice:
	if device_id == KeyboardInput.DEVICE_ID:
		return KeyboardInput.new()
	return GamepadInput.new(device_id)


## Ids of all usable devices: the keyboard first, then every connected gamepad.
static func get_connected_device_ids() -> Array[int]:
	var device_ids: Array[int] = [KeyboardInput.DEVICE_ID]
	device_ids.append_array(Input.get_connected_joypads())
	return device_ids


## Samples the action states for this frame.
func poll() -> void:
	for action in Action.values():
		_previously_held[action] = _held[action]
		_held[action] = _is_action_held(action)
	_accept_previously_held = _accept_held
	_accept_held = _is_accept_held()
	_pointer_motion = _take_pointer_motion()


## Reads the input events the device needs beyond the polled state (e.g. mouse motion).
func handle_input_event(_event: InputEvent) -> void:
	pass


func get_aim_mode() -> AimMode:
	return AimMode.STICK


## Pointer motion since the previous poll, in aim units (a full aim range from the middle to a
## line is 1) with x = right and y = up the screen; zero for a device without a pointer.
func get_pointer_motion() -> Vector2:
	return _pointer_motion


func is_action_held(action: Action) -> bool:
	return _held[action]


func is_action_just_pressed(action: Action) -> bool:
	return _held[action] and not _previously_held[action]


## Whether the menu confirm button was pressed this frame.
func is_accept_just_pressed() -> bool:
	return _accept_held and not _accept_previously_held


## Direction with x = right and y = forward (up on the stick), length in [0, 1].
## The deadzone is removed so small deflections start at zero.
func get_direction() -> Vector2:
	var raw: Vector2 = _read_direction()
	var strength: float = raw.length()
	if strength < DEADZONE:
		return Vector2.ZERO
	return raw / strength * minf(inverse_lerp(DEADZONE, 1.0, strength), 1.0)


## Rumble feedback. Devices without rumble ignore it.
func vibrate(_weak_magnitude: float, _strong_magnitude: float, _duration: float) -> void:
	pass


@abstract func get_device_id() -> int

@abstract func get_display_name() -> String

## Raw direction with x = right and y = forward, length up to 1.
@abstract func _read_direction() -> Vector2

@abstract func _is_action_held(action: Action) -> bool

@abstract func _is_accept_held() -> bool


## Pointer motion collected since the previous poll (see get_pointer_motion); resets it.
func _take_pointer_motion() -> Vector2:
	return Vector2.ZERO
