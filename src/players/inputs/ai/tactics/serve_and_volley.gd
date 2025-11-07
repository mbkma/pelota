extends DefaultTactics


func on_player_ball_hit():
	player.move_to(Vector3(0, 0, sign(player.position.z) * 5))
