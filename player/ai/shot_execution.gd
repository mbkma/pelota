class_name ShotExecution
extends RefCounted


func build_stroke(
	context: AiPointContext,
	targeting: NormalizedCourtTargeting
) -> Stroke:
	if not context or not targeting:
		return null

	var play_style: AiPlayStyle = context.play_style
	var intent: AiPointContext.ShotIntent = context.selected_intent
	var risk: float = context.shot_risk
	var normalized_target: Vector2 = _build_normalized_target(context, intent, risk)

	var stroke := Stroke.new()
	stroke.stroke_type = _determine_stroke_type(context, intent, risk)
	stroke.stroke_power = _compute_power(context, play_style, intent, risk)
	stroke.stroke_spin = _compute_spin(stroke.stroke_type, normalized_target, context, play_style, intent, risk)
	stroke.stroke_target = targeting.to_world_target(
		normalized_target,
		context.player_position,
		context.is_serve
	)
	stroke.step = context.closest_step
	return stroke


func _build_normalized_target(
	context: AiPointContext,
	intent: AiPointContext.ShotIntent,
	risk: float
) -> Vector2:
	var opponent_x: float = context.opponent_position.x
	var away_from_opponent: float = -sign(opponent_x)
	if away_from_opponent == 0.0:
		away_from_opponent = -1.0 if randf() < 0.5 else 1.0

	var lateral_abs: float = lerpf(0.2, 0.96, risk)
	var depth: float = lerpf(0.15, 0.95, risk)

	match intent:
		AiPointContext.ShotIntent.ATTACK:
			lateral_abs = lerpf(0.3, 1.0, risk)
			depth = lerpf(0.45, 1.0, risk)
		AiPointContext.ShotIntent.DEFEND:
			lateral_abs = lerpf(0.08, 0.62, risk)
			depth = lerpf(0.2, 0.72, risk)
		AiPointContext.ShotIntent.APPROACH_NET:
			lateral_abs = lerpf(0.2, 0.75, risk)
			depth = lerpf(0.1, 0.55, risk)
		_:
			pass

	if context.short_ball_opportunity and intent == AiPointContext.ShotIntent.ATTACK and risk > 0.7 and randf() < 0.25:
		depth = -0.85
		lateral_abs = lerpf(0.15, 0.45, risk)

	var jitter_strength: float = lerpf(0.06, 0.2, risk)
	var lateral: float = (away_from_opponent * lateral_abs) + randf_range(-jitter_strength, jitter_strength)
	var target: Vector2 = Vector2(clampf(lateral, -1.0, 1.0), clampf(depth, -1.0, 1.0))

	if context.is_serve:
		var serve_depth: float = lerpf(0.65, 1.0, risk)
		var serve_lateral: float = (away_from_opponent * lerpf(0.1, 0.95, risk)) + randf_range(-0.06, 0.06)
		target = Vector2(clampf(serve_lateral, -1.0, 1.0), clampf(serve_depth, -1.0, 1.0))

	return target


func _determine_stroke_type(
	context: AiPointContext,
	intent: AiPointContext.ShotIntent,
	risk: float
) -> Stroke.StrokeType:
	if context.is_serve:
		return Stroke.StrokeType.SERVE

	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	if intent == AiPointContext.ShotIntent.ATTACK and context.short_ball_opportunity and risk > 0.72 and randf() < 0.22:
		if context.ball_side == AiPointContext.BallSide.BACKHAND:
			return Stroke.StrokeType.BACKHAND_DROP_SHOT
		return Stroke.StrokeType.FOREHAND_DROP_SHOT

	if context.ball_side == AiPointContext.BallSide.BACKHAND:
		if intent == AiPointContext.ShotIntent.DEFEND and movement_pressure > 0.45:
			return Stroke.StrokeType.BACKHAND_SLICE
		return Stroke.StrokeType.BACKHAND

	return Stroke.StrokeType.FOREHAND


func _compute_power(
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	risk: float
) -> float:
	if context.is_serve:
		var serve_power: float = GameConstants.AI_SERVE_PACE * lerpf(0.85, 1.18, risk)
		return clampf(serve_power, 22.0, 40.0)

	var base_power: float = GameConstants.AI_FOREHAND_PACE
	match intent:
		AiPointContext.ShotIntent.ATTACK:
			base_power = 20.0
		AiPointContext.ShotIntent.DEFEND:
			base_power = 15.5
		AiPointContext.ShotIntent.APPROACH_NET:
			base_power = 16.5
		_:
			base_power = 17.5

	var pace_preference: float = 0.5
	if play_style:
		pace_preference = play_style.preferred_rally_pace
	var pace_bias: float = lerpf(0.88, 1.18, pace_preference)
	var risk_bias: float = lerpf(0.82, 1.2, risk)

	var incoming_pressure: float = clampf(inverse_lerp(8.0, 35.0, context.incoming_ball_speed), 0.0, 1.0)
	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	var pressure: float = maxf(incoming_pressure, movement_pressure)
	var control_bias: float = lerpf(0.82, 1.0, 1.0 - pressure)

	var adjusted_power: float = base_power * pace_bias * risk_bias * control_bias
	return clampf(adjusted_power, 8.0, 36.0)


func _compute_spin(
	stroke_type: Stroke.StrokeType,
	normalized_target: Vector2,
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	risk: float
) -> Vector3:
	var side_sign: float = sign(normalized_target.x)
	if side_sign == 0.0:
		side_sign = 1.0

	var topspin: float = lerpf(12.0, 6.0, risk)
	var forward_spin: float = lerpf(0.55, 0.08, risk)
	var side_spin: float = side_sign * lerpf(0.05, 0.35, risk)

	if intent == AiPointContext.ShotIntent.DEFEND:
		topspin += 1.5
		forward_spin += 0.15

	if stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		return Vector3(-0.25 * side_sign, -7.0, 0.25)
	if stroke_type == Stroke.StrokeType.FOREHAND_DROP_SHOT or stroke_type == Stroke.StrokeType.BACKHAND_DROP_SHOT:
		return Vector3(0.08 * side_sign, -8.5, -0.65)
	if stroke_type == Stroke.StrokeType.SERVE:
		var serve_side: float = side_sign * lerpf(0.1, 0.35, risk)
		return Vector3(serve_side, lerpf(1.4, 0.6, risk), lerpf(0.55, 0.2, risk))

	var base_spin: Vector3 = Vector3(side_spin, topspin, forward_spin)
	if context.is_serve:
		return base_spin

	var incoming_pressure: float = clampf(inverse_lerp(8.0, 35.0, context.incoming_ball_speed), 0.0, 1.0)
	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	var pressure: float = maxf(incoming_pressure, movement_pressure)
	var control_window: float = 1.0 - pressure

	var risk_tolerance: float = 0.5
	if play_style:
		risk_tolerance = play_style.risk_tolerance

	var control_bias: float = lerpf(0.88, 1.12, control_window)
	var risk_bias: float = lerpf(0.92, 1.05, risk_tolerance)
	var spin_scale: float = control_bias * risk_bias

	match intent:
		AiPointContext.ShotIntent.ATTACK:
			spin_scale *= 0.95
		AiPointContext.ShotIntent.DEFEND:
			spin_scale *= 1.06
		_:
			pass

	if context.short_ball_opportunity and intent == AiPointContext.ShotIntent.ATTACK:
		spin_scale *= 0.95

	return base_spin * spin_scale
