## Global physics calculations and utilities for ball mechanics
extends Node

## Ball damping factor (energy retention per bounce)
const BALL_DAMP: float = 0.7

## Gravitational acceleration (m/s²)
const GRAVITY: float = 9.81


## Calculates required velocity vector to hit ball from initial position to target
func calculate_velocity(
	initial_position: Vector3, target_position: Vector3, velocity_z0: float, spin: float
) -> Vector3:
	var gravity: float = GRAVITY + _spin_to_gravity(spin)
	var velocity: Vector3 = Vector3.ZERO

	# Time to reach target position
	var time_to_target: float = (target_position.z - initial_position.z) / velocity_z0

	velocity.x = (target_position.x - initial_position.x) / time_to_target
	velocity.y = (
		(0.5 * gravity * time_to_target * time_to_target - initial_position.y) / time_to_target
	)
	velocity.z = velocity_z0

	return velocity


## Converts ball spin value to gravity effect
## Higher spin values increase downward gravity acceleration
func _spin_to_gravity(spin: float) -> float:
	return spin * GameConstants.SPIN_GRAVITY_MULTIPLIER
