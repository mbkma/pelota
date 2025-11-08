class_name DefaultTactics
extends Node

var player: Player

enum AiStrokeType {
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


func compute_next_stroke(closest_step: TrajectoryStep) -> Stroke:
	var r = randf()
	var closest_ball_position := closest_step.point
	var to_ball_vector: Vector3 = closest_ball_position - player.position
	var dot_product: float = to_ball_vector.dot(player.basis.x)
	var stroke: Stroke
	if dot_product > 0:
		if r < 0.3:
			stroke = get_stroke(AiStrokeType.FOREHAND_LONGLINE)
		else:
			stroke = get_stroke(AiStrokeType.FOREHAND_CROSS)
	else:
		if r < 0.2:
			stroke = get_stroke(AiStrokeType.BACKHAND_LONGLINE)
		elif r < 0.4:
			stroke = get_stroke(AiStrokeType.BACKHAND_CROSS)
		elif r < 0.9:
			stroke = get_stroke(AiStrokeType.BACKHAND_SLICE_CROSS)
		else:
			stroke = get_stroke(AiStrokeType.BACKHAND_DROP_SHOT)

	stroke.step = closest_step

	return stroke


func compute_serve() -> Stroke:
	var r = randf()
	if r < 0.4:
		return get_stroke(AiStrokeType.SERVE_WIDE)
	if r < 0.8:
		return get_stroke(AiStrokeType.SERVE_T)
	return get_stroke(AiStrokeType.SERVE_BODY)


func on_player_ball_hit():
	player.move_to(Vector3(sign(player.position.x) * 2, 0, player.position.z))


func get_stroke(stroke_type: AiStrokeType) -> Stroke:
	var stroke := Stroke.new()
	match stroke_type:
		AiStrokeType.FOREHAND_LONGLINE:
			stroke.stroke_type = stroke.StrokeType.FOREHAND
			stroke.stroke_power = player.stats.forehand_pace
			stroke.stroke_spin = player.stats.forehand_spin
			stroke.stroke_target = Vector3(
				sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		AiStrokeType.FOREHAND_CROSS:
			stroke.stroke_type = stroke.StrokeType.FOREHAND
			stroke.stroke_power = player.stats.forehand_pace
			stroke.stroke_spin = player.stats.forehand_spin
			stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		AiStrokeType.BACKHAND_LONGLINE:
			stroke.stroke_type = stroke.StrokeType.BACKHAND
			stroke.stroke_power = player.stats.backhand_pace
			stroke.stroke_spin = player.stats.backhand_spin
			stroke.stroke_target = Vector3(
				sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		AiStrokeType.BACKHAND_CROSS:
			stroke.stroke_type = stroke.StrokeType.BACKHAND
			stroke.stroke_power = player.stats.backhand_pace
			stroke.stroke_spin = player.stats.backhand_spin
			stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		AiStrokeType.BACKHAND_SLICE_CROSS:
			stroke.stroke_type = stroke.StrokeType.BACKHAND_SLICE
			stroke.stroke_power = 20
			stroke.stroke_spin = -5
			stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		AiStrokeType.BACKHAND_SLICE_LONGLINE:
			stroke.stroke_type = stroke.StrokeType.BACKHAND_SLICE
			stroke.stroke_power = 20
			stroke.stroke_spin = -5
			stroke.stroke_target = Vector3(
				sign(player.position.x) * 3, 0, -sign(player.position.z) * standard_length
			)
		AiStrokeType.BACKHAND_DROP_SHOT:
			stroke.stroke_type = stroke.StrokeType.BACKHAND_SLICE
			stroke.stroke_power = 10
			stroke.stroke_spin = -2
			stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * 4
			)
		AiStrokeType.SERVE_WIDE:
			stroke.stroke_type = stroke.StrokeType.SERVE
			stroke.stroke_power = player.stats.serve_pace - 5
			stroke.stroke_spin = 2
			stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * 5
			)
		AiStrokeType.SERVE_T:
			stroke.stroke_type = stroke.StrokeType.SERVE
			stroke.stroke_power = player.stats.serve_pace - 5
			stroke.stroke_spin = 2
			stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * 5
			)
		AiStrokeType.SERVE_BODY:
			stroke.stroke_type = stroke.StrokeType.SERVE
			stroke.stroke_power = player.stats.serve_pace - 5
			stroke.stroke_spin = 2
			stroke.stroke_target = Vector3(
				-sign(player.position.x) * 3, 0, -sign(player.position.z) * 5
			)
		_:
			push_error("AiStroke ", stroke_type, " not implemented!")

	return stroke
