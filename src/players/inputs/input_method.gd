class_name InputMethod
extends Node

var player: Player
var stroke = null


func adjust_player_to_position(position: Vector3):
	# Calculate the direction from the position
	var direction_to_ball: Vector3 = position - player.position

	var left_right_distance: float = direction_to_ball.x * sign(player.position.z)

	var x_offset := 1.0
	if stroke.anim_id == player.model.Strokes.FOREHAND:
		x_offset = player.model.forehand_up_point.x
	else:
		x_offset = player.model.backhand_up_point.x

	var final_move_pos = player.position + (left_right_distance-x_offset) * player.right
	player.move_to(final_move_pos)



func get_closest_ball_position() -> Vector3: # FIXME: Optimize Performance
	# Initialize variables to track the closest point
	var closest_ball_position: Vector3 = Vector3.ZERO
	var closest_z_distance: float = INF # Start with a large number

	# Iterate through the ball trajectory to find the closest point in Z
	for ball_position in player.ball.trajectory:
		# Calculate the Z distance
		var z_distance = abs(ball_position.z - player.position.z)
		
		if z_distance < closest_z_distance:
			closest_z_distance = z_distance
			closest_ball_position = ball_position

	# Now closest_ball_position holds the position of the ball closest to the player in Z
	return closest_ball_position
