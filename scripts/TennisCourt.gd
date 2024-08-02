extends Node

class_name TennisCourt

var court_dimensions: Vector3 = Vector3(23.77, 0, 8.23)  # Tennis court dimensions in meters

func is_in_bounds(ball_position: Vector3) -> bool:
	return abs(ball_position.x) <= court_dimensions.x / 2 and abs(ball_position.z) <= court_dimensions.z / 2

func is_in_service_box(ball_position: Vector3) -> bool:
	# Define service box dimensions and check if ball is within them
	var service_box_dimensions: Vector3 = Vector3(court_dimensions.x / 2, 0, court_dimensions.z / 2)
	return abs(ball_position.x) <= service_box_dimensions.x and abs(ball_position.z) <= service_box_dimensions.z
