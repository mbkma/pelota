## Tennis court geometry and collision zone detection
class_name Court
extends Node3D

## Court boundary and region markers
@onready var _back_sideline: Marker3D = $back_sideline
@onready var _back_left_service_box: Marker3D = $back_left_service_box
@onready var _back_right_service_box: Marker3D = $back_right_service_box
@onready var _front_left_service_box: Marker3D = $front_left_service_box
@onready var _front_right_service_box: Marker3D = $front_right_service_box
@onready var _front_sideline: Marker3D = $front_sideline

## Total field length (net to baseline, both sides)
@onready var _field_length: float = 2 * abs(_front_sideline.position.z)

## Total field width (sideline to sideline)
@onready var _field_width: float = 2 * abs(_front_left_service_box.position.x)

## Service box length (from service line to baseline)
@onready var _service_box_length: float = abs(_back_left_service_box.position.z)

## Service box width (from center to sideline)
@onready var _service_box_width: float = abs(_back_left_service_box.position.x)

## Dictionary of court regions mapped to 2D rectangles for collision detection
var _court_regions: Dictionary[CourtRegion, Rect2] = {}

## Enumeration of distinct court regions for collision detection
enum CourtRegion {
	LEFT_FRONT_SERVICE_BOX,
	RIGHT_FRONT_SERVICE_BOX,
	LEFT_BACK_SERVICE_BOX,
	RIGHT_BACK_SERVICE_BOX,
	BACK_SINGLES_BOX,
	FRONT_SINGLES_BOX,
}


func _ready() -> void:
	Loggie.msg("[Court] field width: ", _field_width).debug()
	
	_court_regions = {
		CourtRegion.LEFT_FRONT_SERVICE_BOX:
		Rect2(
			_front_left_service_box.position.x,
			_front_left_service_box.position.z,
			_service_box_width,
			_service_box_length
		),  # Left service box near the net
		CourtRegion.RIGHT_FRONT_SERVICE_BOX:
		Rect2(
			_front_right_service_box.position.x,
			_front_right_service_box.position.z,
			_service_box_width,
			_service_box_length
		),  # Right service box near the net
		CourtRegion.LEFT_BACK_SERVICE_BOX:
		Rect2(
			_back_left_service_box.position.x,
			_back_left_service_box.position.z,
			_service_box_width,
			_service_box_length
		),  # Left service box near the baseline
		CourtRegion.RIGHT_BACK_SERVICE_BOX:
		Rect2(
			_back_right_service_box.position.x,
			_back_right_service_box.position.z,
			_service_box_width,
			_service_box_length
		),  # Right service box near the baseline
		CourtRegion.BACK_SINGLES_BOX:
		Rect2(
			-_field_width / 2.0,
			_back_sideline.position.z,
			_field_width,
			_field_length / 2.0
		),  # Back singles area (entire back half of the court)
		CourtRegion.FRONT_SINGLES_BOX:
		Rect2(
			-_field_width / 2.0,
			0,
			_field_width,
			_field_length / 2.0
		),  # Front singles area (entire front half of the court)
	}


## Check if ball position is within specified court region
func is_ball_in_court_region(ball_position: Vector3, court_region_enum: CourtRegion) -> bool:
	if court_region_enum not in _court_regions:
		push_error("Invalid court region: ", court_region_enum)
		return false

	var region: Rect2 = _court_regions[court_region_enum]

	# Convert the ball's 3D position to 2D (we only care about X and Z axes)
	var ball_position_2d: Vector2 = Vector2(ball_position.x, ball_position.z)

	return region.has_point(ball_position_2d)
