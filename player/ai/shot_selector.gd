class_name ShotSelector
extends RefCounted

var _targeting := NormalizedCourtTargeting.new()


func select_pattern(
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: ShotPattern.TacticalIntent,
	is_serve: bool
) -> ShotPattern:
	if not context or not play_style:
		return null

	var candidates: Array[ShotPattern] = []
	var weights: Array[float] = []

	for pattern in play_style.get_patterns(is_serve):
		if not pattern:
			continue
		if not pattern.allows_context(context, intent):
			continue

		var score: float = _score_pattern(pattern, context, play_style, intent)
		if score <= 0.0:
			continue
		candidates.append(pattern)
		weights.append(score)

	if candidates.is_empty():
		return null

	return _weighted_pick(candidates, weights)


func _score_pattern(
	pattern: ShotPattern,
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: ShotPattern.TacticalIntent
) -> float:
	var score: float = pattern.base_weight
	score *= play_style.get_intent_weight(intent)

	if context.short_ball_opportunity and intent == ShotPattern.TacticalIntent.ATTACK:
		score *= 1.0 + play_style.aggression

	if pattern.risk_level > play_style.risk_tolerance:
		score *= 0.35

	if context.player_movement_speed > 4.5 and pattern.risk_level > 0.5:
		score *= 0.5

	if context.recovery_distance > 4.0 and pattern.risk_level > 0.6:
		score *= 0.6

	var target: Vector3 = _targeting.to_world_target(pattern.normalized_target, context.player_position, context.is_serve)
	var opponent_distance_to_target: float = context.opponent_position.distance_to(target)
	var spacing_factor: float = clampf(opponent_distance_to_target / (GameConstants.COURT_WIDTH * 0.6), 0.6, 1.4)
	score *= spacing_factor

	var normalized_power: float = inverse_lerp(12.0, 32.0, pattern.stroke_power)
	var pace_alignment: float = 1.0 - absf(normalized_power - play_style.preferred_rally_pace)
	score *= clampf(pace_alignment, 0.4, 1.0)

	if context.ball_height > 1.6 and pattern.stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		score *= 0.6

	if context.opponent_center_distance > 2.8 and intent == ShotPattern.TacticalIntent.ATTACK:
		score *= 1.2

	return maxf(score, 0.0)


func _weighted_pick(candidates: Array[ShotPattern], weights: Array[float]) -> ShotPattern:
	var total: float = 0.0
	for w in weights:
		total += w

	if total <= 0.0:
		return candidates.front()

	var roll: float = randf() * total
	var running: float = 0.0
	for i in range(candidates.size()):
		running += weights[i]
		if roll <= running:
			return candidates[i]

	return candidates.back()
