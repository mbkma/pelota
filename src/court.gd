class_name Court
extends Node3D

@onready var back_sideline: Marker3D = $back_sideline

@onready var back_left_service_box: Marker3D = $back_left_service_box
@onready var back_right_service_box: Marker3D = $back_right_service_box
@onready var front_left_service_box: Marker3D = $front_left_service_box
@onready var front_right_service_box: Marker3D = $front_right_service_box
@onready var front_sideline: Marker3D = $front_sideline

@onready var field_length = 2 * abs(front_sideline.position.z)
@onready var field_width = 2 * abs(front_left_service_box.position.x)

@onready var service_box_length = abs(back_left_service_box.position.z)
@onready var service_box_width = abs(back_left_service_box.position.x)

var court_regions: Dictionary

enum CourtRegion {
	LEFT_FRONT_SERVICE_BOX,
	RIGHT_FRONT_SERVICE_BOX,
	LEFT_BACK_SERVICE_BOX,
	RIGHT_BACK_SERVICE_BOX,
	BACK_SINGLES_BOX,
	FRONT_SINGLES_BOX,
}


func _ready() -> void:
	court_regions = {
		CourtRegion.LEFT_FRONT_SERVICE_BOX:
		Rect2(
			front_left_service_box.position.x,
			front_left_service_box.position.z,
			service_box_width,
			service_box_length
		),  # Left service box near the net
		CourtRegion.RIGHT_FRONT_SERVICE_BOX:
		Rect2(
			front_right_service_box.position.x,
			front_right_service_box.position.z,
			service_box_width,
			service_box_length
		),  # Right service box near the net
		CourtRegion.LEFT_BACK_SERVICE_BOX:
		Rect2(
			back_left_service_box.position.x,
			back_left_service_box.position.z,
			service_box_width,
			service_box_length
		),  # Left service box near the baseline
		CourtRegion.RIGHT_BACK_SERVICE_BOX:
		Rect2(
			back_right_service_box.position.x,
			back_right_service_box.position.z,
			service_box_width,
			service_box_length
		),  # Right service box near the baseline
		CourtRegion.BACK_SINGLES_BOX:
		Rect2(-field_width / 2.0, back_sideline.position.z, field_width, field_length / 2.0),  # Back singles area (entire back half of the court)
		CourtRegion.FRONT_SINGLES_BOX:
		Rect2(-field_width / 2.0, 0, field_width, field_length / 2.0),  # Front singles area (entire front half of the court)
	}


func is_ball_in_court_region(ball_position: Vector3, court_region_enum: CourtRegion) -> bool:
	var region = court_regions[court_region_enum]

	# Convert the ball's 3D position to 2D (we only care about X and Z)
	var ball_position_2d = Vector2(ball_position.x, ball_position.z)

	return region.has_point(ball_position_2d)
