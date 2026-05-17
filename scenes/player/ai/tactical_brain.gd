class_name TacticalBrain
extends RefCounted


func build_candidates(context: AiPointContext, play_style: PlayStyleProfile, stats: PlayerRuntimeStats) -> Array:
	var candidates: Array = []
	if not context:
		return candidates

	if context.is_serve:
		candidates.append(_make_candidate(context, play_style, stats, AiPointContext.ShotIntent.SERVE))
		return candidates

	for intent in [
		AiPointContext.ShotIntent.NEUTRAL,
		AiPointContext.ShotIntent.ATTACK,
		AiPointContext.ShotIntent.DEFEND,
		AiPointContext.ShotIntent.APPROACH_NET,
	]:
		var candidate = _make_candidate(context, play_style, stats, intent)
		if candidate:
			candidates.append(candidate)

	if context.short_ball_opportunity:
		var drop_candidate = _make_candidate(context, play_style, stats, AiPointContext.ShotIntent.NEUTRAL)
		if drop_candidate:
			drop_candidate.tactical_value += 0.12
			drop_candidate.style_preference += _style_drop_bonus(play_style, context)
			drop_candidate.score = _score_candidate(context, play_style, stats, drop_candidate)
			candidates.append(drop_candidate)

	return candidates


func _make_candidate(context: AiPointContext, play_style: PlayStyleProfile, stats: PlayerRuntimeStats, intent: int):
	var candidate = ShotCandidate.new()
	candidate.intent = intent
	candidate.tactical_value = _tactical_value(context, stats, intent)
	candidate.style_preference = _style_preference(context, play_style, intent)
	candidate.comfort = _comfort(context, stats, intent)
	candidate.opponent_exploitation = _opponent_exploitation(context, stats, intent)
	candidate.risk = _risk(context, play_style, stats, intent)
	candidate.execution_difficulty = _execution_difficulty(context, stats, intent)
	candidate.score = _score_candidate(context, play_style, stats, candidate)
	return candidate


func _score_candidate(context: AiPointContext, play_style: PlayStyleProfile, stats: PlayerRuntimeStats, candidate) -> float:
	var pressure: float = 1.0 - context.player_stamina_ratio
	var mental_pressure: float = stats.pressure_resistance01() if stats else 0.5
	var score: float = 0.0
	score += candidate.tactical_value * 0.34
	score += candidate.style_preference * 0.30
	score += candidate.comfort * 0.18
	score += candidate.opponent_exploitation * 0.12
	score -= candidate.risk * 0.22
	score -= candidate.execution_difficulty * 0.16
	score -= pressure * 0.16
	score += mental_pressure * 0.08
	if play_style:
		score += lerpf(0.0, 0.06, play_style.variety)
	return score


func _tactical_value(context: AiPointContext, stats: PlayerRuntimeStats, intent: int) -> float:
	var aggression: float = stats.tactical_aggression01() if stats else 0.5
	var defense: float = stats.tactical_defense01() if stats else 0.5
	var net_play: float = stats.tactical_net_play01() if stats else 0.5
	var value: float = 0.45
	if intent == AiPointContext.ShotIntent.ATTACK:
		value += 0.24 + aggression * 0.16
	if intent == AiPointContext.ShotIntent.DEFEND:
		value += 0.20 + defense * 0.18
	if intent == AiPointContext.ShotIntent.APPROACH_NET:
		value += 0.18 + net_play * 0.16
	if context.short_ball_opportunity:
		value += 0.1
	if context.opponent_center_distance > 2.5:
		value += 0.06
	return clampf(value, 0.0, 1.0)


func _style_preference(context: AiPointContext, play_style: PlayStyleProfile, intent: int) -> float:
	if not play_style:
		return 0.5
	var style_score: float = play_style.aggression
	if intent == AiPointContext.ShotIntent.ATTACK:
		style_score = (style_score * 0.45) + play_style.risk_taking * 0.55
	if intent == AiPointContext.ShotIntent.APPROACH_NET:
		style_score = play_style.net_frequency * 0.6 + play_style.serve_plus_one_aggression * 0.4
	if intent == AiPointContext.ShotIntent.DEFEND:
		style_score = play_style.rally_tolerance * 0.6
	if intent == AiPointContext.ShotIntent.NEUTRAL:
		style_score = play_style.variety * 0.5 + 0.25
	if context.short_ball_opportunity:
		style_score += _style_drop_bonus(play_style, context)
	return clampf(style_score, 0.0, 1.0)


func _style_drop_bonus(play_style: PlayStyleProfile, context: AiPointContext) -> float:
	if not play_style:
		return 0.0
	var bonus: float = 0.0
	bonus += play_style.drop_shot_frequency
	bonus += play_style.backhand_slice_preference if context.ball_side == AiPointContext.BallSide.BACKHAND else 0.0
	return bonus * 0.5


func _comfort(context: AiPointContext, stats: PlayerRuntimeStats, intent: int) -> float:
	var control: float = stats.shot_control01(context.player_stamina_ratio) if stats else 0.5
	var anticipation: float = stats.anticipation01() if stats else 0.5
	var value: float = (control * 0.7) + (anticipation * 0.3)
	if intent == AiPointContext.ShotIntent.DEFEND:
		value += 0.05
	if intent == AiPointContext.ShotIntent.ATTACK:
		value -= 0.04
	return clampf(value, 0.0, 1.0)


func _opponent_exploitation(context: AiPointContext, _stats: PlayerRuntimeStats, intent: int) -> float:
	var value: float = 0.0
	if context.short_ball_opportunity:
		value += 0.16
	if context.opponent_center_distance > 2.8:
		value += 0.18
	if intent == AiPointContext.ShotIntent.APPROACH_NET:
		value += 0.08
	if intent == AiPointContext.ShotIntent.ATTACK and context.ball_side == AiPointContext.BallSide.FOREHAND:
		value += 0.08
	return clampf(value, 0.0, 1.0)


func _risk(context: AiPointContext, play_style: PlayStyleProfile, stats: PlayerRuntimeStats, intent: int) -> float:
	var base_risk: float = 0.45
	if play_style:
		base_risk = play_style.risk_taking * 0.55 + play_style.aggression * 0.45
	if intent == AiPointContext.ShotIntent.ATTACK:
		base_risk += 0.18
	if intent == AiPointContext.ShotIntent.DEFEND:
		base_risk -= 0.14
	if intent == AiPointContext.ShotIntent.APPROACH_NET:
		base_risk += 0.08
	if context.short_ball_opportunity:
		base_risk += 0.08
	var pressure: float = maxf(1.0 - context.player_stamina_ratio, clampf(inverse_lerp(8.0, 35.0, context.incoming_ball_speed), 0.0, 1.0))
	var pressure_resistance: float = stats.pressure_resistance01() if stats else 0.5
	base_risk = lerpf(base_risk, base_risk * lerpf(0.6, 0.9, pressure_resistance), pressure)
	return clampf(base_risk, 0.05, 0.95)


func _execution_difficulty(context: AiPointContext, stats: PlayerRuntimeStats, intent: int) -> float:
	var difficulty: float = 0.35
	difficulty += clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0) * 0.25
	difficulty += clampf(inverse_lerp(8.0, 35.0, context.incoming_ball_speed), 0.0, 1.0) * 0.25
	difficulty += (1.0 - context.player_stamina_ratio) * 0.2
	if intent == AiPointContext.ShotIntent.ATTACK:
		difficulty += 0.08
	if intent == AiPointContext.ShotIntent.DEFEND:
		difficulty -= 0.04
	if stats:
		difficulty -= stats.shot_control01(context.player_stamina_ratio) * 0.16
	return clampf(difficulty, 0.0, 1.0)