class_name MovementService
extends RefCounted

const DISTANCE_THRESHOLD: float = 0.01

var _path: Array[Vector3] = []
var _move_velocity: Vector3 = Vector3.ZERO
var _real_velocity: Vector3 = Vector3.ZERO


func apply_movement(
	body: CharacterBody3D,
	direction: Vector3,
	move_speed: float,
	acceleration: float,
	friction: float
) -> Vector3:
	var animation_direction: Vector3 = direction
	direction = direction.normalized()

	_move_velocity.x = direction.x * move_speed
	_move_velocity.z = direction.z * move_speed

	if direction.length() > 0:
		_real_velocity = _real_velocity.lerp(_move_velocity, acceleration)
	else:
		_real_velocity = _real_velocity.lerp(Vector3.ZERO, friction)

	body.velocity = _real_velocity
	body.move_and_slide()
	return animation_direction


func compute_move_dir(body_position: Vector3) -> Vector3:
	if _path.size() == 0:
		return Vector3.ZERO

	assert(_path.size() == 1)
	return _get_move_direction(body_position)


func request_move_to(target: Vector3) -> void:
	cancel_movement()
	_path.append(target)


func cancel_movement() -> void:
	_path = []


func consume_target_reached_if_needed(body_position: Vector3) -> bool:
	if _path.size() == 0:
		return false

	if body_position.distance_squared_to(_path[0]) < DISTANCE_THRESHOLD:
		_path.remove_at(0)
		return true

	return false


func peek_next_target() -> Variant:
	if _path.size() == 0:
		return null
	return _path[0]


func _get_move_direction(body_position: Vector3) -> Vector3:
	if _path.size() == 0:
		return Vector3.ZERO

	var direction: Vector3 = (_path[0] - body_position).normalized()
	direction.y = 0
	return direction
