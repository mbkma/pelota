## Chooses the intent and target lane of an AI shot from the situation and the play style.
class_name ShotPlanner
extends RefCounted


## Sets `context.intent` and `context.target_lane`.
static func plan(context: AiPointContext) -> void:
	context.intent = _choose_intent(context)
	context.target_lane = _choose_lane(context)


static func _choose_intent(context: AiPointContext) -> AiPointContext.ShotIntent:
	if context.is_serve:
		return AiPointContext.ShotIntent.SERVE

	if _is_defensive_ball(context):
		return AiPointContext.ShotIntent.SAFE

	var attack_probability: float = lerpf(0.2, 0.6, context.play_style.aggression)
	if context.short_ball_opportunity:
		attack_probability = minf(0.92, attack_probability + 0.25)

	return (
		AiPointContext.ShotIntent.ATTACK
		if randf() < attack_probability
		else AiPointContext.ShotIntent.NEUTRAL
	)


static func _choose_lane(context: AiPointContext) -> AiPointContext.TargetLane:
	var aggression: float = context.play_style.aggression
	var cross_weight: float = lerpf(0.7, 0.4, aggression)
	var center_weight: float = lerpf(0.2, 0.1, aggression)
	var line_weight: float = lerpf(0.1, 0.5, aggression)

	if context.intent == AiPointContext.ShotIntent.SAFE:
		cross_weight += 0.12
		center_weight += 0.05
		line_weight -= 0.17
	elif context.intent == AiPointContext.ShotIntent.ATTACK:
		cross_weight -= 0.12
		center_weight -= 0.06
		line_weight += 0.18

	match context.play_style.preferred_pattern:
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

	cross_weight = maxf(cross_weight, 0.01)
	center_weight = maxf(center_weight, 0.01)
	line_weight = maxf(line_weight, 0.01)
	var roll: float = randf() * (cross_weight + center_weight + line_weight)
	if roll < cross_weight:
		return AiPointContext.TargetLane.CROSS
	if roll < cross_weight + center_weight:
		return AiPointContext.TargetLane.CENTER
	return AiPointContext.TargetLane.DOWN_THE_LINE


static func _is_defensive_ball(context: AiPointContext) -> bool:
	return (
		context.player_movement_speed > 4.8
		or context.incoming_ball_speed > 35.0
		or context.player_stamina_ratio < 0.32
	)
