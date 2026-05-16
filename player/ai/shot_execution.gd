class_name ShotExecution
extends RefCounted


func _stats(context: AiPointContext):
	assert(context != null, "ShotExecution._stats: context is required")
	assert(context.player != null, "ShotExecution._stats: context.player is required")
	assert(context.player.stats != null, "ShotExecution._stats: player.stats is required")
	return context.player.stats


func build_stroke(
	context: AiPointContext,
	targeting: NormalizedCourtTargeting
) -> Stroke:
	if not context or not targeting:
		return null

	var play_style: AiPlayStyle = context.play_style
	var intent: AiPointContext.ShotIntent = context.selected_intent
	var risk: float = context.shot_risk
	var intended_normalized_target: Vector2 = _build_normalized_target(context, intent, risk)
	var normalized_target: Vector2 = _apply_target_jitter_to_normalized(intended_normalized_target, context, risk)
	var intended_world_target: Vector3 = targeting.to_world_target(
		intended_normalized_target,
		context.player_position,
		context.is_serve
	)
	var intended_power: float = _compute_power(context, play_style, intent, risk)

	var stroke := Stroke.new()
	stroke.stroke_type = _determine_stroke_type(context, intent, risk)
	stroke.stroke_power = intended_power
	stroke.stroke_spin = _compute_spin(stroke.stroke_type, normalized_target, context, play_style, intent, risk)
	stroke.stroke_target = targeting.to_world_target(
		normalized_target,
		context.player_position,
		context.is_serve
	)
	stroke.intended_stroke_power = intended_power
	stroke.intended_stroke_target = intended_world_target
	_apply_execution_jitter(stroke, context, risk)
	stroke.step = context.closest_step
	return stroke


func _apply_target_jitter_to_normalized(
	normalized_target: Vector2,
	context: AiPointContext,
	risk: float
) -> Vector2:
	var stats = _stats(context)
	var jitter: float = _compute_execution_jitter(context, risk)
	var shot_control: float = stats.shot_control01(context.player_stamina_ratio)
	var pressure_resistance: float = stats.pressure_resistance01()
	var target_error_multiplier: float = lerpf(1.3, 0.5, (shot_control * 0.75) + (pressure_resistance * 0.25))

	# Target jitter in normalized space: lateral/depth execution error.
	var lateral_jitter: float = lerpf(0.02, 0.24, jitter) * target_error_multiplier
	var depth_jitter: float = lerpf(0.01, 0.09, jitter) * target_error_multiplier
	normalized_target.x += randf_range(-lateral_jitter, lateral_jitter)
	normalized_target.y += randf_range(-depth_jitter, depth_jitter)

	# Clamp to normalized court bounds.
	normalized_target = normalized_target.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	return normalized_target


func _apply_execution_jitter(
	stroke: Stroke,
	context: AiPointContext,
	risk: float
) -> void:
	if not stroke:
		return

	var stats = _stats(context)
	var jitter: float = _compute_execution_jitter(context, risk)
	var power_control: float = stats.shot_control01(context.player_stamina_ratio)
	var spin_control: float = stats.spin_control01(stroke.stroke_type, context.player_stamina_ratio)
	var power_error_multiplier: float = lerpf(1.25, 0.6, power_control)
	var spin_error_multiplier: float = lerpf(1.25, 0.58, spin_control)

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


func _compute_execution_jitter(
	context: AiPointContext,
	risk: float
) -> float:
	var stats = _stats(context)
	var incoming_pressure: float = clampf(inverse_lerp(8.0, 35.0, context.incoming_ball_speed), 0.0, 1.0)
	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	var fatigue_pressure: float = 1.0 - context.player_stamina_ratio
	var pressure: float = maxf(maxf(incoming_pressure, movement_pressure), fatigue_pressure)
	var consistency: float = stats.value01(stats.consistency)
	var timing: float = stats.value01(stats.timing)
	var pressure_resistance: float = stats.pressure_resistance01()

	# Higher pressure and high-risk intent increase error; consistency, timing and composure reduce it.
	var jitter: float = 0.05
	jitter += pressure * 0.55
	jitter += risk * 0.25
	jitter *= lerpf(1.22, 0.62, (consistency * 0.6) + (timing * 0.25) + (pressure_resistance * 0.15))

	if context.is_serve:
		jitter *= 0.86

	return clampf(jitter, 0.03, 0.95)


func _build_normalized_target(
	context: AiPointContext,
	intent: AiPointContext.ShotIntent,
	risk: float
) -> Vector2:
	var stats = _stats(context)
	var player_side_x: float = sign(context.player_position.x)
	if player_side_x == 0.0:
		player_side_x = 1.0

	var half_court_width: float = maxf(1.0, GameConstants.COURT_WIDTH * 0.5)
	var opponent_world_x01: float = clampf(context.opponent_position.x / half_court_width, -1.0, 1.0)
	var opponent_world_side: float = sign(opponent_world_x01)
	if opponent_world_side == 0.0:
		opponent_world_side = -1.0 if randf() < 0.5 else 1.0
	var open_world_side: float = -opponent_world_side
	var open_relative_side: float = open_world_side * player_side_x
	var opponent_displacement01: float = abs(opponent_world_x01)

	var aggression01: float = stats.tactical_aggression01()
	var net_play01: float = stats.tactical_net_play01()
	var defense01: float = stats.tactical_defense01()
	var control01: float = stats.shot_control01(context.player_stamina_ratio)
	var line_bias: float = clampf((aggression01 * 0.65) + ((1.0 - control01) * 0.35), 0.0, 1.0)

	var lateral_abs: float = lerpf(0.2, 0.9, risk)
	var depth: float = lerpf(0.2, 0.92, risk)

	match intent:
		AiPointContext.ShotIntent.ATTACK:
			lateral_abs = lerpf(0.32, 1.0, risk)
			depth = lerpf(0.48, 1.0, risk)
		AiPointContext.ShotIntent.DEFEND:
			lateral_abs = lerpf(0.08, 0.58, risk)
			depth = lerpf(0.18, 0.7, risk)
		AiPointContext.ShotIntent.APPROACH_NET:
			lateral_abs = lerpf(0.2, 0.72, risk)
			depth = lerpf(0.08, 0.52, risk)
		_:
			pass

	# Aggressive low-control players target closer to lines; precise players choose safer depth/lateral windows.
	lateral_abs = lerpf(lateral_abs * 0.88, minf(1.0, lateral_abs * 1.08), line_bias)
	depth = lerpf(depth * 0.88, minf(1.0, depth * 1.06), line_bias)

	# Cross-court is the default safe lane; down-the-line needs higher risk/aggression.
	var cross_court_score: float = 0.45
	cross_court_score += (1.0 - risk) * 0.45
	cross_court_score += defense01 * 0.22
	cross_court_score += (1.0 - line_bias) * 0.12

	var down_the_line_score: float = 0.12
	down_the_line_score += risk * 0.5
	down_the_line_score += aggression01 * 0.25
	down_the_line_score += line_bias * 0.18

	var open_side_bonus: float = opponent_displacement01 * (0.24 + (aggression01 * 0.16) + (risk * 0.1))
	if open_relative_side < 0.0:
		cross_court_score += open_side_bonus
	else:
		down_the_line_score += open_side_bonus

	var lateral_side: float = -1.0 if cross_court_score >= down_the_line_score else 1.0

	if intent == AiPointContext.ShotIntent.APPROACH_NET:
		depth *= lerpf(0.9, 0.75, net_play01)

	if intent == AiPointContext.ShotIntent.DEFEND:
		depth = lerpf(depth, depth * 0.86, defense01)

	# If the opponent is stretched far wide, use a shorter angle to the open court.
	if intent != AiPointContext.ShotIntent.DEFEND and opponent_displacement01 > 0.62:
		lateral_side = open_relative_side
		lateral_abs = maxf(lateral_abs, lerpf(0.68, 0.95, opponent_displacement01))
		var short_angle_depth: float = lerpf(0.42, 0.16, opponent_displacement01)
		depth = minf(depth, short_angle_depth)

	if context.short_ball_opportunity and intent == AiPointContext.ShotIntent.ATTACK and risk > 0.68 and randf() < (0.12 + net_play01 * 0.22):
		depth = -0.85
		lateral_abs = lerpf(0.14, 0.42, risk)

	var lateral: float = lateral_side * lateral_abs
	var target: Vector2 = Vector2(clampf(lateral, -1.0, 1.0), clampf(depth, -1.0, 1.0))

	if context.is_serve:
		var serve_accuracy01: float = stats.serve_accuracy01(context.player_stamina_ratio)
		var serve_depth: float = lerpf(0.62, 1.0, risk)
		var serve_lateral: float = sign(context.opponent_position.x) * lerpf(0.12, 0.95, risk)
		serve_lateral = lerpf(serve_lateral * 0.86, serve_lateral, serve_accuracy01)
		target = Vector2(clampf(serve_lateral, -1.0, 1.0), clampf(serve_depth, -1.0, 1.0))

	return target


func _determine_stroke_type(
	context: AiPointContext,
	intent: AiPointContext.ShotIntent,
	risk: float
) -> Stroke.StrokeType:
	if context.is_serve:
		return Stroke.StrokeType.SERVE

	var stats = _stats(context)
	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	var stamina_pressure: float = 1.0 - context.player_stamina_ratio
	var net_play01: float = stats.tactical_net_play01()
	var slice_skill01: float = stats.value01(stats.slice_skill)

	# Drop shots become more available to touch players when short balls are available.
	var drop_shot_chance: float = 0.0
	if context.short_ball_opportunity:
		drop_shot_chance += lerpf(0.02, 0.14, risk)
		drop_shot_chance += net_play01 * 0.14
		drop_shot_chance += slice_skill01 * 0.08
		match intent:
			AiPointContext.ShotIntent.ATTACK:
				drop_shot_chance += 0.10
			AiPointContext.ShotIntent.NEUTRAL:
				drop_shot_chance += 0.04
			AiPointContext.ShotIntent.APPROACH_NET:
				drop_shot_chance += 0.08
			_:
				pass

	if randf() < clampf(drop_shot_chance, 0.0, 0.5):
		if context.ball_side == AiPointContext.BallSide.BACKHAND:
			return Stroke.StrokeType.BACKHAND_DROP_SHOT
		return Stroke.StrokeType.FOREHAND_DROP_SHOT

	if context.ball_side == AiPointContext.BallSide.BACKHAND:
		# Slices appear more under pressure and with strong slice skill.
		var slice_chance: float = 0.03
		slice_chance += lerpf(0.1, 0.0, risk)
		slice_chance += movement_pressure * 0.18
		slice_chance += stamina_pressure * 0.08
		slice_chance += slice_skill01 * 0.22
		if context.ball_height > 1.1:
			slice_chance += 0.06
		if intent == AiPointContext.ShotIntent.DEFEND:
			slice_chance += 0.14
		elif intent == AiPointContext.ShotIntent.NEUTRAL:
			slice_chance += 0.05

		if randf() < clampf(slice_chance, 0.0, 0.68):
			return Stroke.StrokeType.BACKHAND_SLICE
		return Stroke.StrokeType.BACKHAND

	return Stroke.StrokeType.FOREHAND


func _compute_power(
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	risk: float
) -> float:
	var stats = _stats(context)
	if context.is_serve:
		var serve_power_skill: float = stats.serve_power01()
		var serve_stamina: float = context.player_stamina_ratio
		var serve_power: float = lerpf(24.0, 39.0, serve_power_skill)
		serve_power *= lerpf(0.9, 1.18, risk)
		serve_power *= lerpf(0.82, 1.0, 1.0 - serve_stamina)
		return clampf(serve_power, 22.0, 40.0)

	var side_quality: float = stats.shot_side_skill01(context.ball_side == AiPointContext.BallSide.BACKHAND)
	var tactical_aggression: float = stats.tactical_aggression01()
	var base_power: float = lerpf(19.5, 30.0, side_quality)

	var intent_power_multiplier: float = 1.0
	match intent:
		AiPointContext.ShotIntent.ATTACK:
			intent_power_multiplier = 1.22
		AiPointContext.ShotIntent.DEFEND:
			intent_power_multiplier = 0.78
		AiPointContext.ShotIntent.APPROACH_NET:
			intent_power_multiplier = 0.86
		_:
			intent_power_multiplier = 1.0

	var pace_preference: float = 0.5
	if play_style:
		pace_preference = play_style.preferred_rally_pace
	var pace_bias: float = lerpf(0.88, 1.18, (pace_preference * 0.45) + (tactical_aggression * 0.55))
	var risk_bias: float = lerpf(0.82, 1.2, risk)

	var incoming_pressure: float = clampf(inverse_lerp(8.0, 35.0, context.incoming_ball_speed), 0.0, 1.0)
	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	var pressure: float = maxf(incoming_pressure, movement_pressure)
	var control_bias: float = lerpf(0.8, 1.02, 1.0 - pressure)
	var stamina_bias: float = lerpf(0.76, 1.0, context.player_stamina_ratio)

	var adjusted_power: float = base_power * intent_power_multiplier * pace_bias * risk_bias * control_bias * stamina_bias
	return clampf(adjusted_power, 8.0, 36.0)


func _compute_spin(
	stroke_type: Stroke.StrokeType,
	normalized_target: Vector2,
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	risk: float
) -> Vector3:
	var stats = _stats(context)
	var side_sign: float = sign(normalized_target.x)
	if side_sign == 0.0:
		side_sign = 1.0

	var topspin_skill: float = stats.value01(stats.topspin_skill)
	var slice_skill: float = stats.value01(stats.slice_skill)
	var topspin: float = lerpf(13.0, 6.0, risk) * lerpf(0.86, 1.18, topspin_skill)
	var forward_spin: float = lerpf(0.6, 0.08, risk)
	var side_spin: float = side_sign * lerpf(0.06, 0.38, risk)

	if intent == AiPointContext.ShotIntent.DEFEND:
		topspin += 1.5
		forward_spin += 0.16

	if stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		var slice_depth: float = lerpf(-5.8, -9.4, slice_skill)
		return Vector3(-0.28 * side_sign, slice_depth, 0.25)
	if stroke_type == Stroke.StrokeType.FOREHAND_DROP_SHOT or stroke_type == Stroke.StrokeType.BACKHAND_DROP_SHOT:
		var touch: float = lerpf(0.85, 1.2, stats.tactical_net_play01())
		return Vector3(0.08 * side_sign, -8.2 * touch, -0.65)
	if stroke_type == Stroke.StrokeType.SERVE:
		var serve_side: float = side_sign * lerpf(0.1, 0.35, risk)
		var serve_spin_quality: float = (stats.serve_accuracy01(context.player_stamina_ratio) * 0.65) + (topspin_skill * 0.35)
		return Vector3(serve_side, lerpf(1.5, 0.65, risk), lerpf(0.55, 0.2, risk)) * lerpf(0.88, 1.12, serve_spin_quality)

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
	spin_scale *= lerpf(0.82, 1.08, stats.spin_control01(stroke_type, context.player_stamina_ratio))

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
