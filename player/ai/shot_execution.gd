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
	_apply_execution_jitter(stroke, context, risk)
	stroke.step = context.closest_step
	return stroke


func _apply_execution_jitter(
	stroke: Stroke,
	context: AiPointContext,
	risk: float
) -> void:
	if not stroke:
		return

	var jitter: float = _compute_execution_jitter(context, risk)
	var power_precision: float = _get_player_stat01(context, "power_precision", 75.0)
	var spin_precision: float = _get_player_stat01(context, "spin_precision", 75.0)
	var target_precision: float = _get_player_stat01(context, "target_precision", 75.0)
	var power_error_multiplier: float = lerpf(1.25, 0.65, power_precision)
	var spin_error_multiplier: float = lerpf(1.25, 0.65, spin_precision)
	var target_error_multiplier: float = lerpf(1.25, 0.65, target_precision)

	# Power jitter: multiplicative error around intended pace.
	var power_jitter: float = lerpf(0.02, 0.16, jitter) * power_error_multiplier
	stroke.stroke_power *= (1.0 + randf_range(-power_jitter, power_jitter))
	stroke.stroke_power = clampf(stroke.stroke_power, 8.0, 40.0)

	# Spin jitter: small scale and additive perturbation on each axis.
	var spin_scale_jitter: float = lerpf(0.02, 0.18, jitter) * spin_error_multiplier
	stroke.stroke_spin *= Vector3(
		1.0 + randf_range(-spin_scale_jitter, spin_scale_jitter),
		1.0 + randf_range(-spin_scale_jitter, spin_scale_jitter),
		1.0 + randf_range(-spin_scale_jitter, spin_scale_jitter)
	)
	var spin_additive: float = lerpf(0.05, 0.8, jitter) * spin_error_multiplier
	stroke.stroke_spin += Vector3(
		randf_range(-spin_additive, spin_additive),
		randf_range(-spin_additive * 2.0, spin_additive * 2.0),
		randf_range(-spin_additive, spin_additive)
	)

	# Target jitter: lateral/depth execution error while keeping shot on opponent side.
	var lateral_jitter: float = (GameConstants.COURT_WIDTH * 0.5) * lerpf(0.02, 0.22, jitter) * target_error_multiplier
	var depth_jitter: float = GameConstants.COURT_LENGTH_HALF * lerpf(0.01, 0.08, jitter) * target_error_multiplier
	stroke.stroke_target.x += randf_range(-lateral_jitter, lateral_jitter)
	stroke.stroke_target.z += randf_range(-depth_jitter, depth_jitter)

	var half_width: float = (GameConstants.COURT_WIDTH * 0.5) - 0.2
	stroke.stroke_target.x = clampf(stroke.stroke_target.x, -half_width, half_width)

	var striker_side_z: float = sign(context.player_position.z)
	if striker_side_z == 0.0:
		striker_side_z = 1.0
	var opponent_side_z: float = -striker_side_z
	var target_depth_abs: float = clampf(absf(stroke.stroke_target.z), 0.5, GameConstants.COURT_LENGTH_HALF - 0.2)
	stroke.stroke_target.z = opponent_side_z * target_depth_abs


func _compute_execution_jitter(
	context: AiPointContext,
	risk: float
) -> float:
	var incoming_pressure: float = clampf(inverse_lerp(8.0, 35.0, context.incoming_ball_speed), 0.0, 1.0)
	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	var pressure: float = maxf(incoming_pressure, movement_pressure)
	var execution_consistency: float = _get_player_stat01(context, "execution_consistency", 75.0)

	# Higher pressure and high-risk intent increase error; consistent players reduce it.
	var jitter: float = 0.06
	jitter += pressure * 0.55
	jitter += risk * 0.25
	jitter *= lerpf(1.25, 0.55, execution_consistency)

	if context.is_serve:
		jitter *= 0.85

	return clampf(jitter, 0.03, 0.95)


func _get_player_stat01(context: AiPointContext, key: String, default_score: float) -> float:
	if not context or not context.player:
		return clampf(default_score / 100.0, 0.0, 1.0)

	var player_stats: Dictionary = context.player.stats
	if not player_stats.has(key):
		return clampf(default_score / 100.0, 0.0, 1.0)

	var raw_value: float = float(player_stats.get(key, default_score))
	if raw_value >= 0.0 and raw_value <= 1.0:
		return raw_value
	return clampf(raw_value / 100.0, 0.0, 1.0)


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

	var lateral: float = (away_from_opponent * lateral_abs)
	var target: Vector2 = Vector2(clampf(lateral, -1.0, 1.0), clampf(depth, -1.0, 1.0))

	if context.is_serve:
		var serve_depth: float = lerpf(0.65, 1.0, risk)
		var serve_lateral: float = (sign(opponent_x) * lerpf(0.1, 0.95, risk))
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

	# Drop shots are more common on short balls, but still possible outside strict attack intent.
	var drop_shot_chance: float = 0.0
	if context.short_ball_opportunity:
		drop_shot_chance += lerpf(0.03, 0.18, risk)
		match intent:
			AiPointContext.ShotIntent.ATTACK:
				drop_shot_chance += 0.10
			AiPointContext.ShotIntent.NEUTRAL:
				drop_shot_chance += 0.05
			AiPointContext.ShotIntent.APPROACH_NET:
				drop_shot_chance += 0.04
			_:
				pass

	if randf() < clampf(drop_shot_chance, 0.0, 0.45):
		if context.ball_side == AiPointContext.BallSide.BACKHAND:
			return Stroke.StrokeType.BACKHAND_DROP_SHOT
		return Stroke.StrokeType.FOREHAND_DROP_SHOT

	if context.ball_side == AiPointContext.BallSide.BACKHAND:
		# Slices can appear in neutral phases too; pressure and defensive intent raise frequency.
		var slice_chance: float = 0.03
		slice_chance += lerpf(0.08, 0.0, risk)  # Safer players slice more often.
		slice_chance += movement_pressure * 0.20
		if context.ball_height > 1.1:
			slice_chance += 0.06
		if intent == AiPointContext.ShotIntent.DEFEND:
			slice_chance += 0.14
		elif intent == AiPointContext.ShotIntent.NEUTRAL:
			slice_chance += 0.05

		if randf() < clampf(slice_chance, 0.0, 0.55):
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

	var base_power: float = 25.0
	var intent_power_multiplier: float = 1.0
	match intent:
		AiPointContext.ShotIntent.ATTACK:
			intent_power_multiplier = 1.2
		AiPointContext.ShotIntent.DEFEND:
			intent_power_multiplier = 0.775
		AiPointContext.ShotIntent.APPROACH_NET:
			intent_power_multiplier = 0.825
		_:
			intent_power_multiplier = 1

	var pace_preference: float = 0.5
	if play_style:
		pace_preference = play_style.preferred_rally_pace
	var pace_bias: float = lerpf(0.88, 1.18, pace_preference)
	var risk_bias: float = lerpf(0.82, 1.2, risk)

	var incoming_pressure: float = clampf(inverse_lerp(8.0, 35.0, context.incoming_ball_speed), 0.0, 1.0)
	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	var pressure: float = maxf(incoming_pressure, movement_pressure)
	var control_bias: float = lerpf(0.82, 1.0, 1.0 - pressure)

	var adjusted_power: float = base_power * intent_power_multiplier * pace_bias * risk_bias * control_bias
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
