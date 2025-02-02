class_name DefaultTactics
extends Node

var player: Player


func setup(_player) -> void:
	player = _player


func compute_next_stroke(pred) -> Dictionary:
	var r = randf()
	if sign(player.position.z) * (pred.pos.x - player.position.x) > 0:
		if r < 0.3:
			return player.strokes.forehand_longline()
		else:
			return player.strokes.forehand_cross()
	else:
		if r < 0.2:
			return player.strokes.backhand_longline()
		elif r < 0.4:
			return player.strokes.backhand_cross()
		elif r < 0.9:
			return player.strokes.backhand_slice_cross()
		else:
			return player.strokes.backhand_stop()


func compute_serve() -> Dictionary:
	var r = randf()
	if r < 0.3:
		return player.strokes.serve_wide()
	elif r < 0.6:
		return player.strokes.serve_t()
	else:
		return player.strokes.serve_body()


func on_Player_ball_hit():
	player.move_to(Vector3(sign(player.position.x) * 2, 0, player.position.z))
