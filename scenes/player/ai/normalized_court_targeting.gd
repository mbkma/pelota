class_name NormalizedCourtTargeting
extends RefCounted

var _lateral_margin: float = 0.75
var _short_depth: float = GameConstants.AI_STROKE_DROP_DISTANCE
var _deep_depth: float = GameConstants.AI_STROKE_STANDARD_LENGTH
var _serve_depth: float = 6.0


func to_world_target(normalized_target: Vector2, striker_position: Vector3, is_serve: bool) -> Vector3:
	var side_x: float = sign(striker_position.x)
	if side_x == 0.0:
		side_x = 1.0

	var side_z: float = sign(striker_position.z)
	if side_z == 0.0:
		side_z = 1.0

	var clamped_target := Vector2(clampf(normalized_target.x, -1.0, 1.0), clampf(normalized_target.y, -1.0, 1.0))
	var half_court_width: float = (GameConstants.COURT_WIDTH * 0.5) - _lateral_margin
	var world_x: float = side_x * clamped_target.x * half_court_width

	var world_z: float = 0.0
	if is_serve:
		world_z = -side_z * _serve_depth
	else:
		var depth_t: float = (clamped_target.y + 1.0) * 0.5
		world_z = -side_z * lerpf(_short_depth, _deep_depth, depth_t)

	return Vector3(world_x, 0.0, world_z)
