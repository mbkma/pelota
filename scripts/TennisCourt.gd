class_name TennisCourt extends Node

var court_dimensions: Vector3 = Vector3(10.97, 0, 23.77)  # Tennis court dimensions in meters

var serve_positions: Dictionary = {
	1:
	[
		Vector3(-court_dimensions.x / 4, 0, -court_dimensions.z / 2),
		Vector3(court_dimensions.x / 4, 0, -court_dimensions.z / 2)
	],
	2:
	[
		Vector3(court_dimensions.x / 4, 0, court_dimensions.z / 2),
		Vector3(-court_dimensions.x / 4, 0, court_dimensions.z / 2)
	]
}
var return_positions: Dictionary = {
	1:
	[
		Vector3(-court_dimensions.x / 4, 0, -court_dimensions.z / 2),
		Vector3(court_dimensions.x / 4, 0, -court_dimensions.z / 2)
	],
	2:
	[
		Vector3(court_dimensions.x / 4, 0, court_dimensions.z / 2),
		Vector3(-court_dimensions.x / 4, 0, court_dimensions.z / 2)
	]
}


func is_in_bounds(ball_position: Vector3) -> bool:
	return (
		abs(ball_position.x) <= court_dimensions.x / 2
		and abs(ball_position.z) <= court_dimensions.z / 2
	)


func is_in_service_box(ball_position: Vector3) -> bool:
	var service_box_dimensions: Vector3 = Vector3(court_dimensions.x / 2, 0, court_dimensions.z / 2)
	return (
		abs(ball_position.x) <= service_box_dimensions.x
		and abs(ball_position.z) <= service_box_dimensions.z
	)


# Get serve position based on current player and score
func get_serve_position(player: int, game: int) -> Vector3:
	return serve_positions[player][game % 2]


# Get return position based on current player and score
func get_return_position(player: int, game: int) -> Vector3:
	return return_positions[player][game % 2]
