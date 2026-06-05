## Realistic movement controller with ATP-based physics.
## Handles acceleration, deceleration, and direction changes with stamina scaling.
## 
## Movement Parameters (ATP-based):
## - move_speed: max sustained speed (m/s), realistic: 6.0 = ~21.6 km/h
## - acceleration: rate of speed gain (m/s²), realistic: 15.0 m/s²
## - friction: deceleration rate (m/s²), realistic: 12.0 m/s²
class_name MovementController
extends RefCounted

var _path: Array[Vector3] = []
var _velocity: Vector3 = Vector3.ZERO
var _last_direction: Vector3 = Vector3.ZERO
var _direction_change_time: float = 0.0
const DIRECTION_CHANGE_PENALTY_DURATION: float = 0.15  # seconds to apply penalty


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


## Advance velocity for one physics frame using realistic acceleration physics.
## Stamina affects max speed, acceleration, and direction change ability.
##
## Parameters:
## - direction: input direction (will be normalized)
## - stats: player stats for stamina scaling
## - stamina01: stamina ratio [0, 1]
## - move_speed: base max speed (m/s)
## - acceleration: base accel rate (m/s²)
## - friction: base decel rate (m/s²)
## - delta: frame time delta (seconds)
func tick(
	direction: Vector3,
	stats: PlayerRuntimeStats,
	stamina01: float,
	move_speed: float,
	acceleration: float,
	friction: float,
	delta: float
) -> Vector3:
	direction = direction.normalized()
	
	# Stamina scaling: maintain ability at ~60% stamina, degrade to 50% at 0% stamina
	var stamina_speed_factor: float = lerpf(0.5, 1.0, stamina01)
	var stamina_accel_factor: float = lerpf(0.5, 1.0, stamina01)
	
	# Apply stats multipliers
	var effective_max_speed: float = move_speed * stats.movement_speed_multiplier(stamina01) * stamina_speed_factor
	var effective_acceleration: float = acceleration * stats.acceleration_multiplier(stamina01) * stamina_accel_factor
	var effective_friction: float = friction
	
	# Detect direction change: sharp turns apply extra braking
	var direction_change_angle: float = 0.0
	if _last_direction.length_squared() > 0.01 and direction.length_squared() > 0.01:
		direction_change_angle = _last_direction.angle_to(direction)
	
	# Apply direction change penalty (extra braking on sharp turns)
	if direction_change_angle > 0.5:  # ~30 degrees
		_direction_change_time = DIRECTION_CHANGE_PENALTY_DURATION
	
	# Reduce acceleration during direction changes
	if _direction_change_time > 0.0:
		effective_acceleration *= 0.6  # Slower acceleration while turning
		_direction_change_time -= delta
	
	# Compute target velocity based on input direction
	var target_velocity: Vector3 = direction * effective_max_speed
	target_velocity.y = _velocity.y  # Preserve vertical velocity
	
	# Accelerate or decelerate toward target using physics-based approach
	if direction.length() > 0.001:
		# Accelerate toward target velocity
		var acceleration_vector: Vector3 = (target_velocity - _velocity).normalized() * effective_acceleration
		_velocity += acceleration_vector * delta
		
		# Clamp to target speed
		var horizontal_speed: float = Vector3(_velocity.x, 0.0, _velocity.z).length()
		if horizontal_speed > effective_max_speed:
			var horizontal_vel: Vector3 = Vector3(_velocity.x, 0.0, _velocity.z).normalized() * effective_max_speed
			_velocity.x = horizontal_vel.x
			_velocity.z = horizontal_vel.z
	else:
		# Decelerate to zero
		var deceleration_vector: Vector3 = -_velocity.normalized() * effective_friction
		var new_velocity: Vector3 = _velocity + deceleration_vector * delta
		
		# Stop if we've reached near-zero
		if new_velocity.length() < 0.1:
			_velocity = Vector3.ZERO
		else:
			_velocity = new_velocity
	
	_last_direction = direction
	return _velocity
