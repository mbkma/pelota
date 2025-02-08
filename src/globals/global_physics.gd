extends Node

var DAMP := 0.7
const GRAVITY: float = 9.81  # Gravity in m/s^2


func calculate_velocity(
	initial_position: Vector3, target_position: Vector3, v_z0: float, spin: float
) -> Vector3:
	var gravity := GRAVITY + spin
	var vel := Vector3.ZERO

	# Time to reach target_position
	var t_1 = (target_position.z - initial_position.z) / v_z0

	vel.x = (target_position.x - initial_position.x) / t_1
	vel.y = (0.5 * gravity * t_1 * t_1 - initial_position.y) / t_1
	vel.z = v_z0

	return vel
