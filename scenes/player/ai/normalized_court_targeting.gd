class_name NormalizedCourtTargeting
extends RefCounted


func to_world_target(normalized_target: Vector2, striker_position: Vector3, is_serve: bool) -> Vector3:
	var clamped_x: float = clampf(normalized_target.x, -1.0, 1.0)
	var clamped_y: float = clampf(normalized_target.y, 0.0, 1.0)

	var width: float = GameConstants.COURT_WIDTH_HALF
	var length: float = GameConstants.COURT_LENGTH_HALF
	if is_serve:
		length = GameConstants.SERVICE_LINE
	var opponent_side: float = -1.0 if striker_position.z >= 0.0 else 1.0

	var world_x: float = clamped_x * width
	var world_z: float = lerpf(0.0, length * opponent_side, clamped_y)

	return Vector3(world_x, striker_position.y, world_z)
