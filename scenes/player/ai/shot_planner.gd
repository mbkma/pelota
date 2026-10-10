## Chooses the intent and target lane of an AI shot from the situation and the play style. The
## AI watches the opponent: it plays into the open court the farther the opponent is out of
## position, and it uses a short ball: it attacks it, and with the opponent in position it plays
## a short angle cross court to pull the opponent out wide for the next shot.
class_name ShotPlanner
extends RefCounted

## Chance that a fully deep incoming ball is played safe; a deep ball is not attacked.
const DEEP_BALL_SAFE_CHANCE: float = 0.75
## A player needing more than this share of the time until contact to get to the ball is
## stretched and plays safe.
const STRETCHED: float = 0.85
## Attack chance on a full chance (a short ball), and how much an opponent fully out of position
## adds to it.
const OPPORTUNITY_ATTACK_CHANCE: float = 0.9
const OUT_OF_POSITION_ATTACK_CHANCE: float = 0.3
## Weight added to the lane into the open court for an opponent fully out of position; the other
## lanes weigh about 1 in total.
const OPEN_COURT_WEIGHT: float = 4.0
## Chance of a short angle on an attacked short ball with the opponent in position, from the
## least to the most aggressive play style. From AiPointContext.opportunity ANGLE_MIN_OPPORTUNITY
## on the ball is short enough to angle.
const ANGLE_CHANCE: Vector2 = Vector2(0.45, 0.8)
const ANGLE_MIN_OPPORTUNITY: float = 0.5


## Sets `context.intent`, then aims (see aim).
static func plan(context: AiPointContext) -> void:
	context.intent = _choose_intent(context)
	aim(context)


## Sets `context.target_lane` and `context.is_angle` for the intent of `context`.
static func aim(context: AiPointContext) -> void:
	context.target_lane = _choose_lane(context)
	context.is_angle = _plays_angle(context)
	if context.is_angle:
		context.target_lane = AiPointContext.TargetLane.CROSS


static func _choose_intent(context: AiPointContext) -> AiPointContext.ShotIntent:
	if context.is_serve:
		return AiPointContext.ShotIntent.SERVE

	if _is_defensive_ball(context) or randf() < context.depth_pressure * DEEP_BALL_SAFE_CHANCE:
		return AiPointContext.ShotIntent.SAFE

	var attack_probability: float = lerpf(0.2, 0.6, context.play_style.aggression)
	attack_probability = lerpf(attack_probability, OPPORTUNITY_ATTACK_CHANCE, context.opportunity)
	attack_probability += OUT_OF_POSITION_ATTACK_CHANCE * context.opponent_out_of_position
	attack_probability *= 1.0 - context.depth_pressure

	return (
		AiPointContext.ShotIntent.ATTACK
		if randf() < attack_probability
		else AiPointContext.ShotIntent.NEUTRAL
	)


static func _choose_lane(context: AiPointContext) -> AiPointContext.TargetLane:
	var aggression: float = context.play_style.aggression
	var weights: Dictionary[AiPointContext.TargetLane, float] = {
		AiPointContext.TargetLane.CROSS: lerpf(0.7, 0.4, aggression),
		AiPointContext.TargetLane.CENTER: lerpf(0.2, 0.1, aggression),
		AiPointContext.TargetLane.DOWN_THE_LINE: lerpf(0.1, 0.5, aggression),
	}

	if context.intent == AiPointContext.ShotIntent.SAFE:
		weights[AiPointContext.TargetLane.CROSS] += 0.12
		weights[AiPointContext.TargetLane.CENTER] += 0.05
		weights[AiPointContext.TargetLane.DOWN_THE_LINE] -= 0.17
	elif context.intent == AiPointContext.ShotIntent.ATTACK:
		weights[AiPointContext.TargetLane.CROSS] -= 0.12
		weights[AiPointContext.TargetLane.CENTER] -= 0.06
		weights[AiPointContext.TargetLane.DOWN_THE_LINE] += 0.18

	match context.play_style.preferred_pattern:
		AiPlayStyle.PreferredPattern.CROSS_CROSS:
			weights[AiPointContext.TargetLane.CROSS] += 0.15
			weights[AiPointContext.TargetLane.CENTER] -= 0.05
			weights[AiPointContext.TargetLane.DOWN_THE_LINE] -= 0.1
		AiPlayStyle.PreferredPattern.FOREHAND_INSIDE_OUT:
			if context.ball_side == AiPointContext.BallSide.FOREHAND:
				weights[AiPointContext.TargetLane.DOWN_THE_LINE] += 0.15
				weights[AiPointContext.TargetLane.CROSS] -= 0.1
			else:
				weights[AiPointContext.TargetLane.CROSS] += 0.08

	# The open court: the lane away from the opponent.
	for lane in weights:
		weights[lane] = maxf(weights[lane], 0.01)
		if context.open_side != 0.0 and context.lane_side(lane) == context.open_side:
			weights[lane] += OPEN_COURT_WEIGHT * context.opponent_out_of_position

	var total: float = 0.0
	for lane in weights:
		total += weights[lane]
	var roll: float = randf() * total
	for lane in weights:
		roll -= weights[lane]
		if roll < 0.0:
			return lane
	return AiPointContext.TargetLane.DOWN_THE_LINE


## Whether an attacked short ball is played as a short angle: with the opponent in position, it
## is pulled out wide so the next ball can go into the open court.
static func _plays_angle(context: AiPointContext) -> bool:
	if context.intent != AiPointContext.ShotIntent.ATTACK or context.is_volley():
		return false
	if context.opportunity < ANGLE_MIN_OPPORTUNITY or context.opponent_out_of_position > 0.5:
		return false
	return randf() < lerpf(ANGLE_CHANCE.x, ANGLE_CHANCE.y, context.play_style.aggression)


static func _is_defensive_ball(context: AiPointContext) -> bool:
	return (
		context.stretch > STRETCHED
		or context.incoming_ball_speed > 35.0
		or context.player_stamina_ratio < 0.32
	)
