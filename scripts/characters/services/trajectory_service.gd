class_name TrajectoryService
extends RefCounted


func get_closest_step(controller: Controller, player: Player) -> TrajectoryStep:
	if controller and controller.has_method("get_closest_trajectory_step"):
		return controller.get_closest_trajectory_step(player)
	return null


func is_ball_in_reachable_window(ball: Ball, player_position: Vector3, max_distance: float = 3.0) -> bool:
	if not ball:
		return false

	var dist: float = ball.global_position.distance_to(player_position)
	return dist < max_distance
