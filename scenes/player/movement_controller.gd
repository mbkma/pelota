## Encapsulates movement state and stats-driven velocity computation for a player.
## Player owns an instance and delegates all path/velocity logic here.
class_name MovementController
extends RefCounted

var _path: Array[Vector3] = []
var _move_velocity: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _last_move_direction: Vector3 = Vector3.ZERO


## Returns the current computed velocity (used by stamina drain calculations).
func get_velocity() -> Vector3:
	return _velocity


## Returns the next movement target, or null if no target is queued.
func peek_next_target() -> Variant:
	if _path.is_empty():
		return null
	return _path[0]


## Returns the current path as a copy (single entry or empty).
func get_path() -> Array[Vector3]:
	if _path.is_empty():
		return []
	return [_path[0]]


## Queue movement to the given target, replacing any existing target.
func request_move_to(target: Vector3) -> void:
	_path.clear()
	_path.append(target)


## Cancel all pending movement.
func cancel() -> void:
	_path.clear()


## Check whether body_position has reached the current target.
## If so, removes the target and returns true.
func check_and_consume_reached(body_position: Vector3, threshold_sq: float) -> bool:
	if _path.is_empty():
		return false
	if body_position.distance_squared_to(_path[0]) < threshold_sq:
		_path.remove_at(0)
		return true
	return false


## Compute the normalized direction toward the current movement target.
func compute_direction(body_position: Vector3) -> Vector3:
	if _path.is_empty():
		return Vector3.ZERO
	var direction: Vector3 = (_path[0] - body_position).normalized()
	direction.y = 0.0
	return direction


## Advance velocity for one physics frame given an input direction and player state.
## Returns the resulting velocity to assign to CharacterBody3D.velocity.
func tick(
	direction: Vector3,
	stats: PlayerRuntimeStats,
	stamina01: float,
	move_speed: float,
	acceleration: float,
	friction: float
) -> Vector3:
	direction = direction.normalized()

	var direction_change: float = 0.0
	if _last_move_direction.length_squared() > 0.001 and direction.length_squared() > 0.001:
		direction_change = clampf((_last_move_direction - direction).length() * 0.5, 0.0, 1.0)

	var change_penalty: float = 1.0 - (stats.direction_change_resistance(stamina01) * direction_change)
	var speed_scalar: float = stats.movement_speed_multiplier(stamina01) * change_penalty
	var acceleration_scalar: float = stats.acceleration_multiplier(stamina01)

	_move_velocity.x = direction.x * move_speed * speed_scalar
	_move_velocity.z = direction.z * move_speed * speed_scalar

	if direction.length() > 0.0:
		_velocity = _velocity.lerp(_move_velocity, clampf(acceleration * acceleration_scalar, 0.01, 1.0))
	else:
		_velocity = _velocity.lerp(Vector3.ZERO, friction)

	if direction.length_squared() > 0.001:
		_last_move_direction = direction
	else:
		_last_move_direction = _last_move_direction.lerp(Vector3.ZERO, 0.2)

	return _velocity
