## Where a human player aims a shot or serve within its target area (see HumanController), moved
## the way the device aims (see InputDevice.AimMode):
## - Stick: the direction sets an aim goal per axis that is kept while the direction eases back
##   toward neutral; the aim moves toward that goal at SPEED. Full deflection in any direction
##   reaches the edge of the target area (diagonals reach the corners).
## - Pointer: the pointer motion moves the aim.
## - Zones: the direction held picks one of nine zones (no direction: the middle).
## Directions and the pointer motion are relative to the player (x = right, y = forward).
class_name ShotAim
extends RefCounted

## How fast the aim moves toward its goal, in aim ranges (center to line) per second.
const SPEED: float = 1.4
## Direction axis values below this count as neutral.
const NEUTRAL: float = 0.05
## An aim axis only follows the direction while it stays above this share of the push's peak,
## so the aim holds while the stick springs back.
const RELEASE_RATIO: float = 0.9
## Share of a full direction from which an axis counts toward a zone: a diagonal picks a corner.
const ZONE_THRESHOLD: float = 0.38

## Aim within the target area: x = left/right, y = short/deep, each in [-1, 1].
var value: Vector2 = Vector2.ZERO
## Where the aim is moving to, set by the direction (stick).
var _goal: Vector2 = Vector2.ZERO
## Peak deflection per axis of the current push of the direction (stick).
var _peak: Vector2 = Vector2.ZERO


func update(
	mode: InputDevice.AimMode, direction: Vector2, pointer_motion: Vector2, delta: float
) -> void:
	match mode:
		InputDevice.AimMode.STICK:
			_follow_stick(direction, delta)
		InputDevice.AimMode.POINTER:
			value = (value + pointer_motion).clamp(-Vector2.ONE, Vector2.ONE)
		InputDevice.AimMode.ZONES:
			value = Vector2(_zone_axis(direction.x), _zone_axis(direction.y))


## Back to the middle.
func reset() -> void:
	value = Vector2.ZERO
	_goal = Vector2.ZERO
	_peak = Vector2.ZERO


## Zone (-1, 0 or 1) a direction axis picks.
static func _zone_axis(axis_value: float) -> float:
	return signf(axis_value) if absf(axis_value) >= ZONE_THRESHOLD else 0.0


func _follow_stick(direction: Vector2, delta: float) -> void:
	var largest_axis: float = maxf(absf(direction.x), absf(direction.y))
	if largest_axis == 0.0:
		_peak = Vector2.ZERO
	else:
		var square: Vector2 = direction / largest_axis * direction.length()
		_follow_stick_axis(Vector2.AXIS_X, square.x)
		_follow_stick_axis(Vector2.AXIS_Y, square.y)
	value = value.move_toward(_goal, SPEED * delta)


func _follow_stick_axis(axis: int, axis_value: float) -> void:
	var magnitude: float = absf(axis_value)
	if magnitude < NEUTRAL:
		_peak[axis] = 0.0
		return
	if signf(axis_value) != signf(_goal[axis]):
		# Pushing to the other side starts a new push.
		_peak[axis] = 0.0
	if magnitude >= _peak[axis] * RELEASE_RATIO:
		_peak[axis] = maxf(_peak[axis], magnitude)
		_goal[axis] = axis_value
