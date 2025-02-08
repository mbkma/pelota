class_name DefaultTactics
extends Node

var player: Player

enum StrokeType {
	FOREHAND_LONGLINE,
	FOREHAND_CROSS,
	BACKHAND_LONGLINE,
	BACKHAND_CROSS,
	BACKHAND_SLICE_CROSS,
	BACKHAND_SLICE_LONGLINE,
	BACKHAND_DROP_SHOT,
	SERVE_WIDE,
	SERVE_T,
	SERVE_BODY,
}

var standard_length := 10.0


func setup(_player) -> void:
	player = _player


func compute_next_stroke(closest_ball_position) -> void:
	var r = randf()
	var to_ball_vector: Vector3 = closest_ball_position - player.position
	var dot_product: float = to_ball_vector.dot(player.basis.x)
	if dot_product > 0:
		if r < 0.3:
			set_stroke(StrokeType.FOREHAND_LONGLINE)
		else:
			set_stroke(StrokeType.FOREHAND_CROSS)
	else:
		if r < 0.2:
			set_stroke(StrokeType.BACKHAND_LONGLINE)
		elif r < 0.4:
			set_stroke(StrokeType.BACKHAND_CROSS)
		elif r < 0.9:
			set_stroke(StrokeType.BACKHAND_SLICE_CROSS)
		else:
			return set_stroke(StrokeType.BACKHAND_DROP_SHOT)


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


func set_stroke(stroke_type: StrokeType):
	match stroke_type:
		StrokeType.FOREHAND_LONGLINE:
			player.stroke.stroke_type = player.stroke.StrokeType.FOREHAND
			player.stroke.stroke_power = player.stats.forehand_pace
			player.stroke.stroke_spin = player.stats.forehand_spin
			player.stroke.stroke_target = Vector3(
				sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		StrokeType.FOREHAND_CROSS:
			player.stroke.stroke_type = player.stroke.StrokeType.FOREHAND
			player.stroke.stroke_power = player.stats.forehand_pace
			player.stroke.stroke_spin = player.stats.forehand_spin
			var target_local = Vector3(-8 * 0.3, 0, -11)  # Cross direction
			var target_global = player.global_position + player.global_basis * target_local
			player.stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		StrokeType.BACKHAND_LONGLINE:
			player.stroke.stroke_type = player.stroke.StrokeType.BACKHAND
			player.stroke.stroke_power = player.stats.backhand_pace
			player.stroke.stroke_spin = player.stats.backhand_spin
			player.stroke.stroke_target = Vector3(
				sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		StrokeType.BACKHAND_CROSS:
			player.stroke.stroke_type = player.stroke.StrokeType.BACKHAND
			player.stroke.stroke_power = player.stats.backhand_pace
			player.stroke.stroke_spin = player.stats.backhand_spin
			player.stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		StrokeType.BACKHAND_SLICE_CROSS:
			player.stroke.stroke_type = player.stroke.StrokeType.BACKHAND_SLICE
			player.stroke.stroke_power = 20
			player.stroke.stroke_spin = -5
			player.stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		StrokeType.BACKHAND_SLICE_LONGLINE:
			player.stroke.stroke_type = player.stroke.StrokeType.BACKHAND_SLICE
			player.stroke.stroke_power = 20
			player.stroke.stroke_spin = -5
			player.stroke.stroke_target = Vector3(
				sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		StrokeType.BACKHAND_DROP_SHOT:
			player.stroke.stroke_type = player.stroke.StrokeType.BACKHAND_SLICE
			player.stroke.stroke_power = 10
			player.stroke.stroke_spin = -2
			player.stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * 4
			)
