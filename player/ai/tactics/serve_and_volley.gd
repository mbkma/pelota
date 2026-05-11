extends DefaultTactics


func choose_tactical_intent(context: AiPointContext) -> ShotPattern.TacticalIntent:
	if context.is_serve:
		return ShotPattern.TacticalIntent.SERVE

	if context.short_ball_opportunity:
		return ShotPattern.TacticalIntent.APPROACH_NET

	if context.ball_height > 0.4 and context.ball_height < 1.4:
		return ShotPattern.TacticalIntent.APPROACH_NET

	return ShotPattern.TacticalIntent.ATTACK
