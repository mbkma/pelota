## Realistic movement controller based on tennis sprint data.
## Handles acceleration, deceleration, and direction changes with stamina scaling.
##
## Movement Parameters (base values, scaled by the player's stats):
## - move_speed: top speed running forward (m/s), ~5.5-6.5 m/s for pros over a few meters
## - acceleration: rate of speed gain (m/s²), ~11-14 m/s² (5 m sprint in ~1.0 s)
## - friction: deceleration rate without input (m/s²)
## Players run fastest toward the net, slower sideways (side steps / crossovers) and slowest
## backpedalling.
class_name MovementController
extends RefCounted

const DIRECTION_CHANGE_PENALTY_DURATION: float = 0.15  # seconds to apply penalty
## Braking (m/s²) the arrival at a movement target is planned with: the player runs as fast as
## it can still stop at the target, so it neither crawls the last meter nor overshoots.
const ARRIVAL_DECELERATION: float = 8.0
## Share of the top speed reached moving sideways and backward (forward is 1.0).
const LATERAL_SPEED_FACTOR: float = 0.8
const BACKWARD_SPEED_FACTOR: float = 0.6

## Current movement target, null while there is none.
var _target: Variant = null
var _velocity: Vector3 = Vector3.ZERO
var _last_direction: Vector3 = Vector3.ZERO
var _direction_change_time: float = 0.0


## Returns the current computed velocity (used by stamina drain calculations).
func get_velocity() -> Vector3:
	return _velocity


## Current movement target, null while there is none.
func get_target() -> Variant:
	return _target


## Move to the given target, replacing any existing target.
func request_move_to(target: Vector3) -> void:
	_target = target


## Cancel the pending movement.
func cancel() -> void:
	_target = null


## Cancel movement and clear residual velocity for precise timing windows.
func stop() -> void:
	_target = null
	_reset_momentum()


## Drops the current target once body_position is within sqrt(threshold_sq) of it.
func check_and_consume_reached(body_position: Vector3, threshold_sq: float) -> void:
	if _target != null and body_position.distance_squared_to(_target) < threshold_sq:
		_target = null
		_reset_momentum()


func _reset_momentum() -> void:
	_velocity = Vector3.ZERO
	_last_direction = Vector3.ZERO
	_direction_change_time = 0.0


## Direction toward the current movement target, its length the share of `max_speed` that
## still allows stopping at the target.
func compute_direction(body_position: Vector3, max_speed: float) -> Vector3:
	if _target == null:
		return Vector3.ZERO

	var offset: Vector3 = _target - body_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance <= 0.0001:
		return Vector3.ZERO

	var stopping_speed: float = sqrt(2.0 * ARRIVAL_DECELERATION * distance)
	var input_strength: float = clampf(stopping_speed / maxf(max_speed, 0.001), 0.0, 1.0)
	return offset.normalized() * input_strength


## Advance velocity for one physics frame using realistic acceleration physics.
## Stamina affects max speed, acceleration, and direction change ability.
##
## Parameters:
## - direction: input direction (will be normalized)
## - facing: horizontal direction the player faces (toward the net)
## - stats: player stats for stamina scaling
## - stamina01: stamina ratio [0, 1]
## - move_speed: base max speed running forward (m/s)
## - acceleration: base accel rate (m/s²)
## - friction: deceleration without input (m/s²)
func tick(
	direction: Vector3,
	facing: Vector3,
	stats: PlayerRuntimeStats,
	stamina01: float,
	move_speed: float,
	acceleration: float,
	friction: float
) -> Vector3:
	var delta: float = 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	var input_strength: float = clampf(direction.length(), 0.0, 1.0)
	var move_direction: Vector3 = Vector3.ZERO
	if input_strength > 0.001:
		move_direction = direction / input_strength

	# Stamina scaling: maintain ability at ~60% stamina, degrade to 50% at 0% stamina
	var stamina_speed_factor: float = lerpf(0.5, 1.0, stamina01)
	var stamina_accel_factor: float = lerpf(0.5, 1.0, stamina01)

	# Apply stats multipliers
	var effective_max_speed: float = (
		move_speed
		* stats.movement_speed_multiplier(stamina01)
		* stamina_speed_factor
		* _direction_speed_factor(move_direction, facing)
	)
	var effective_acceleration: float = (
		acceleration * stats.acceleration_multiplier(stamina01) * stamina_accel_factor
	)

	# Detect direction change: sharp turns apply extra braking
	var direction_change_angle: float = 0.0
	if _last_direction.length_squared() > 0.01 and move_direction.length_squared() > 0.01:
		direction_change_angle = _last_direction.angle_to(move_direction)

	# Apply direction change penalty (extra braking on sharp turns)
	if direction_change_angle > 0.5:  # ~30 degrees
		_direction_change_time = DIRECTION_CHANGE_PENALTY_DURATION

	# Reduce acceleration during direction changes; agile players lose less
	if _direction_change_time > 0.0:
		effective_acceleration *= 1.0 - stats.direction_change_resistance(stamina01)
		_direction_change_time -= delta

	# Compute target velocity based on input direction
	var target_velocity: Vector3 = move_direction * effective_max_speed * input_strength
	target_velocity.y = _velocity.y  # Preserve vertical velocity

	# Accelerate or decelerate toward target using physics-based approach
	if input_strength > 0.001:
		# Accelerate toward target velocity
		var acceleration_vector: Vector3 = (
			(target_velocity - _velocity).normalized() * effective_acceleration
		)
		_velocity += acceleration_vector * delta

		# Clamp to target speed
		var horizontal_speed: float = Vector3(_velocity.x, 0.0, _velocity.z).length()
		if horizontal_speed > effective_max_speed:
			var horizontal_vel: Vector3 = (
				Vector3(_velocity.x, 0.0, _velocity.z).normalized() * effective_max_speed
			)
			_velocity.x = horizontal_vel.x
			_velocity.z = horizontal_vel.z
	else:
		# Decelerate to zero
		var deceleration_vector: Vector3 = -_velocity.normalized() * friction
		var new_velocity: Vector3 = _velocity + deceleration_vector * delta

		# Stop if we've reached near-zero
		if new_velocity.length() < 0.1:
			_velocity = Vector3.ZERO
		else:
			_velocity = new_velocity

	_last_direction = move_direction
	return _velocity


## Share of the forward top speed reachable moving in `move_direction`: full toward the net,
## LATERAL_SPEED_FACTOR sideways, BACKWARD_SPEED_FACTOR away from the net, blended in between.
func _direction_speed_factor(move_direction: Vector3, facing: Vector3) -> float:
	if move_direction.length_squared() < 0.0001:
		return 1.0
	var alignment: float = move_direction.dot(facing)
	var straight_factor: float = 1.0 if alignment >= 0.0 else BACKWARD_SPEED_FACTOR
	return lerpf(LATERAL_SPEED_FACTOR, straight_factor, alignment * alignment)
