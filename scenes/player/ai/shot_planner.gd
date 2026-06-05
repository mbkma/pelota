class_name ShotPlanner
extends RefCounted


func build_shot_plan(context: AiPointContext, play_style: AiPlayStyle) -> Dictionary:
	if not context:
		return {}

	var intent: int = _choose_intent(context, play_style)
	var lane: int = _choose_lane(context, play_style, intent)
	var risk: float = _intent_risk(intent, play_style)
	var intent_name: String = AiPointContext.ShotIntent.keys()[intent]
	var lane_name: String = AiPointContext.TargetLane.keys()[lane]
	var debug: String = "%s lane=%s risk=%.2f" % [intent_name, lane_name, risk]

	return {
		"intent": intent,
		"target_lane": lane,
		"risk": risk,
		"debug": debug,
	}


func _choose_intent(context: AiPointContext, play_style: AiPlayStyle) -> int:
	if context.is_serve:
		return AiPointContext.ShotIntent.SERVE

	if _is_defensive_ball(context):
		return AiPointContext.ShotIntent.SAFE

	var aggression: float = play_style.aggression if play_style else 0.5
	var attack_probability: float = lerpf(0.2, 0.6, aggression)
	if context.short_ball_opportunity:
		attack_probability = minf(0.92, attack_probability + 0.25)

	return AiPointContext.ShotIntent.ATTACK if randf() < attack_probability else AiPointContext.ShotIntent.NEUTRAL


func _choose_lane(context: AiPointContext, play_style: AiPlayStyle, intent: int) -> int:
	var aggression: float = play_style.aggression if play_style else 0.5
	var cross_weight: float = lerpf(0.7, 0.4, aggression)
	var center_weight: float = lerpf(0.2, 0.1, aggression)
	var line_weight: float = lerpf(0.1, 0.5, aggression)

	if intent == AiPointContext.ShotIntent.SAFE:
		cross_weight += 0.12
		center_weight += 0.05
		line_weight -= 0.17
	elif intent == AiPointContext.ShotIntent.ATTACK:
		cross_weight -= 0.12
		center_weight -= 0.06
		line_weight += 0.18

	if play_style:
		match play_style.preferred_pattern:
			AiPlayStyle.PreferredPattern.CROSS_CROSS:
				cross_weight += 0.15
				center_weight -= 0.05
				line_weight -= 0.1
			AiPlayStyle.PreferredPattern.FOREHAND_INSIDE_OUT:
				if context.ball_side == AiPointContext.BallSide.FOREHAND:
					line_weight += 0.15
					cross_weight -= 0.1
				else:
					cross_weight += 0.08
			_:
				pass

	cross_weight = maxf(cross_weight, 0.01)
	center_weight = maxf(center_weight, 0.01)
	line_weight = maxf(line_weight, 0.01)
	var total: float = cross_weight + center_weight + line_weight
	var roll: float = randf() * total
	if roll < cross_weight:
		return AiPointContext.TargetLane.CROSS
	roll -= cross_weight
	if roll < center_weight:
		return AiPointContext.TargetLane.CENTER
	return AiPointContext.TargetLane.DOWN_THE_LINE


func _is_defensive_ball(context: AiPointContext) -> bool:
	var stretched_by_movement: bool = context.player_movement_speed > 4.8
	var stretched_by_ball_speed: bool = context.incoming_ball_speed > 35.0
	var stretched_by_stamina: bool = context.player_stamina_ratio < 0.32
	return stretched_by_movement or stretched_by_ball_speed or stretched_by_stamina


func _intent_risk(intent: int, play_style: AiPlayStyle) -> float:
	if intent == AiPointContext.ShotIntent.SAFE:
		return 0.2
	if intent == AiPointContext.ShotIntent.ATTACK:
		return 0.85
	var aggression: float = play_style.aggression if play_style else 0.5
	return lerpf(0.45, 0.65, aggression)
