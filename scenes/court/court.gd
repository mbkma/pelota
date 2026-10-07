## Tennis court regions (service boxes and singles halves) built from the court markers.
class_name Court
extends Node3D

enum CourtRegion {
	LEFT_FRONT_SERVICE_BOX,
	RIGHT_FRONT_SERVICE_BOX,
	LEFT_BACK_SERVICE_BOX,
	RIGHT_BACK_SERVICE_BOX,
	BACK_SINGLES_BOX,
	FRONT_SINGLES_BOX,
}

## Court regions as rectangles on the ground (x, z)
var _court_regions: Dictionary[CourtRegion, Rect2] = {}


func _ready() -> void:
	var front_left_box: Vector3 = $front_left_service_box.position
	var front_right_box: Vector3 = $front_right_service_box.position
	var back_left_box: Vector3 = $back_left_service_box.position
	var back_right_box: Vector3 = $back_right_service_box.position
	var half_length: float = absf($front_sideline.position.z)
	var field_width: float = 2.0 * absf(front_left_box.x)
	var box_size := Vector2(absf(back_left_box.x), absf(back_left_box.z))

	_court_regions = {
		CourtRegion.LEFT_FRONT_SERVICE_BOX: Rect2(_ground(front_left_box), box_size),
		CourtRegion.RIGHT_FRONT_SERVICE_BOX: Rect2(_ground(front_right_box), box_size),
		CourtRegion.LEFT_BACK_SERVICE_BOX: Rect2(_ground(back_left_box), box_size),
		CourtRegion.RIGHT_BACK_SERVICE_BOX: Rect2(_ground(back_right_box), box_size),
		CourtRegion.BACK_SINGLES_BOX:
		Rect2(-field_width / 2.0, $back_sideline.position.z, field_width, half_length),
		CourtRegion.FRONT_SINGLES_BOX: Rect2(-field_width / 2.0, 0.0, field_width, half_length),
	}


func is_ball_in_court_region(ball_position: Vector3, court_region: CourtRegion) -> bool:
	return _court_regions[court_region].has_point(_ground(ball_position))


func _ground(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)
