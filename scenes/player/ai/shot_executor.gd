class_name ShotExecutor
extends RefCounted

## When true, intended shot equals executed shot (no jitter or consistency error)
var perfect_accuracy: bool = false


func _stats(context: AiPointContext) -> PlayerRuntimeStats:
	assert(context != null, "ShotExecutor._stats: context is required")
	assert(context.player != null, "ShotExecutor._stats: context.player is required")
	assert(context.player.stats != null, "ShotExecutor._stats: player.stats is required")
	return context.player.stats


func _apply_execution_jitter(stroke: Stroke, context: AiPointContext, risk: float) -> void:
	if not stroke or not context or perfect_accuracy:
		return
	var consistency: float = 0.5
	if context.play_style:
		consistency = context.play_style.consistency
	var error_radius: float = lerpf(3.0, 0.2, consistency)
	error_radius *= lerpf(0.7, 1.1, clampf(risk, 0.0, 1.0))
	stroke.stroke_target += Vector3(
		randf_range(-error_radius, error_radius), 0.0, randf_range(-error_radius, error_radius)
	)
	if not context.is_serve:
		stroke.stroke_target.z *= lerpf(0.72, 1.0, consistency)


func build_stroke(context: AiPointContext, targeting: NormalizedCourtTargeting) -> Stroke:
	if not context or not targeting:
		return null

	var play_style: AiPlayStyle = context.play_style
	var intent: AiPointContext.ShotIntent = context.selected_intent
	var lane: AiPointContext.TargetLane = context.selected_target_lane
	var normalized_target: Vector2 = _build_normalized_target(context, play_style, intent, lane)
	var intended_world_target: Vector3 = targeting.to_world_target(
		normalized_target, context.player_position, context.is_serve
	)
	var actual_target: Vector3 = (
		intended_world_target
		if perfect_accuracy
		else _apply_consistency_error(intended_world_target, context, play_style)
	)
	var stroke_type: Stroke.StrokeType = _determine_stroke_type(context, intent)
	var intended_power: float = _compute_shot_speed(context, play_style, intent, stroke_type)

	var stroke := Stroke.new()
	stroke.stroke_type = stroke_type
	stroke.intended_stroke_target = intended_world_target
	stroke.stroke_target = actual_target
	stroke.intended_stroke_power = intended_power
	stroke.stroke_power = intended_power
	stroke.stroke_spin = _compute_shot_spin(
		context, play_style, intent, normalized_target.x, stroke_type
	)
	stroke.stroke_intent = intent
	stroke.step = context.closest_step
	return stroke


func _build_normalized_target(
	context: AiPointContext,
	_play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	lane: AiPointContext.TargetLane
) -> Vector2:
	if context.is_serve:
		var serve_side_sign: float = sign(context.player.position.x)
		return Vector2(-serve_side_sign * 0.5, 0.9)

	var lane_sign: float = 0.0
	match lane:
		AiPointContext.TargetLane.CROSS:
			lane_sign = -1.0
		AiPointContext.TargetLane.DOWN_THE_LINE:
			lane_sign = 1.0
		_:
			lane_sign = 0.0

	var lateral_abs: float = 0.75
	var depth: float = 0.8
	match intent:
		AiPointContext.ShotIntent.SAFE:
			lateral_abs = 0.38
			depth = 0.75
		AiPointContext.ShotIntent.NEUTRAL:
			lateral_abs = 0.75
			depth = 0.8
		AiPointContext.ShotIntent.ATTACK:
			lateral_abs = 0.9
			depth = maxf(0.6, randf())
		_:
			pass

	#if context.short_ball_opportunity and intent == AiPointContext.ShotIntent.ATTACK:
	#depth = minf(depth, 0.7)

	#var court_bias: float = play_style.court_position if play_style else 0.0
	#depth = clampf(depth + (court_bias * 0.22), -1.0, 1.0)

	return Vector2(clampf(lane_sign * lateral_abs, -1.0, 1.0), depth)


func _determine_stroke_type(
	context: AiPointContext, intent: AiPointContext.ShotIntent
) -> Stroke.StrokeType:
	if context.is_serve:
		return Stroke.StrokeType.SERVE

	if context.ball_side == AiPointContext.BallSide.BACKHAND:
		if intent == AiPointContext.ShotIntent.SAFE and randf() < 0.45:
			return Stroke.StrokeType.BACKHAND_SLICE
		return Stroke.StrokeType.BACKHAND

	return Stroke.StrokeType.FOREHAND


func _compute_shot_speed(
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	stroke_type: Stroke.StrokeType
) -> float:
	var stats = _stats(context)
	if context.is_serve:
		var serve_skill: float = stats.serve_power01()
		var base_serve: float = lerpf(48.0, 52.0, serve_skill)
		var serve_style_power: float = play_style.shot_power if play_style else 0.5
		var serve_speed: float = base_serve + (serve_style_power * 4.0)
		serve_speed *= lerpf(0.88, 1.0, context.player_stamina_ratio)
		return clampf(serve_speed, 24.0, 64.0)

	var side_quality: float = stats.shot_side_skill01(
		context.ball_side == AiPointContext.BallSide.BACKHAND
	)
	var base_speed: float = lerpf(24.0, 29.0, side_quality)
	var style_power: float = play_style.shot_power if play_style else 0.5
	var intent_power_bonus: float = 12.0
	match intent:
		AiPointContext.ShotIntent.SAFE:
			intent_power_bonus = 6.0
		AiPointContext.ShotIntent.NEUTRAL:
			intent_power_bonus = 12.0
		AiPointContext.ShotIntent.ATTACK:
			intent_power_bonus = 18.0
		_:
			pass

	var shot_speed: float = base_speed + (style_power * intent_power_bonus)
	shot_speed *= lerpf(0.86, 1.0, context.player_stamina_ratio)
	if stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		shot_speed *= 0.7
		return clampf(shot_speed, 9.0, 25.0)
	return clampf(shot_speed, 13.0, 38.0)


func _compute_shot_spin(
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	normalized_x: float,
	stroke_type: Stroke.StrokeType
) -> Vector3:
	var stats = _stats(context)
	var topspin_skill: float = stats.spin_control01(stroke_type, context.player_stamina_ratio)
	var style_topspin: float = play_style.topspin if play_style else 0.5
	var style_aggression: float = play_style.aggression if play_style else 0.5
	var side_sign: float = sign(normalized_x)
	if side_sign == 0.0:
		side_sign = 1.0

	if stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		return Vector3(-0.22 * side_sign, -0.86, 0.0)
	if stroke_type == Stroke.StrokeType.SERVE:
		var serve_topspin: float = lerpf(0.55, 0.9, style_topspin)
		var serve_side: float = side_sign * lerpf(0.08, 0.3, style_aggression)
		return Vector3(serve_side, serve_topspin, 0.0)

	var base_topspin: float = lerpf(0.46, 0.88, topspin_skill)
	var intent_spin_bonus: float = 0.3
	match intent:
		AiPointContext.ShotIntent.SAFE:
			intent_spin_bonus = 0.6
		AiPointContext.ShotIntent.NEUTRAL:
			intent_spin_bonus = 0.3
		AiPointContext.ShotIntent.ATTACK:
			intent_spin_bonus = 0.12
		_:
			pass

	var topspin_value: float = clampf(base_topspin + (style_topspin * intent_spin_bonus), -1.0, 1.0)
	var side_spin: float = side_sign * lerpf(0.04, 0.24, style_aggression)
	return Vector3(0, topspin_value, 0.0)


func _apply_consistency_error(
	intended_target: Vector3, context: AiPointContext, play_style: AiPlayStyle
) -> Vector3:
	var consistency: float = play_style.consistency if play_style else 0.5
	var error_radius: float = lerpf(1.0, 0.2, consistency)
	var target: Vector3 = intended_target

	if context.is_serve:
		error_radius *= 0.1

	target += Vector3(
		randf_range(-error_radius, error_radius), 0.0, randf_range(-error_radius, error_radius)
	)

	return target
