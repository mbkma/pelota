class_name AiPointContext
extends RallyContext

enum BallSide {
	FOREHAND,
	BACKHAND,
}

enum ShotIntent {
	NEUTRAL,
	ATTACK,
	DEFEND,
	APPROACH_NET,
	SERVE,
}

var short_ball_opportunity: bool = false
var ball_side: BallSide = BallSide.FOREHAND
var selected_intent: ShotIntent = ShotIntent.NEUTRAL
var shot_risk: float = 0.5
var play_style: PlayStyleProfile


static func from_step(target_player: Player, step: TrajectoryStep, serve: bool = false) -> AiPointContext:
	var context := AiPointContext.new()

	# Copy base positional/state fields from RallyContext to avoid duplication.
	var base: RallyContext = RallyContext.from_player_step(target_player, step, serve)
	context.player = base.player
	context.opponent = base.opponent
	context.closest_step = base.closest_step
	context.is_serve = base.is_serve
	context.player_position = base.player_position
	context.opponent_position = base.opponent_position
	context.ball_position = base.ball_position
	context.incoming_ball_speed = base.incoming_ball_speed
	context.ball_height = base.ball_height
	context.player_movement_speed = base.player_movement_speed
	context.player_stamina_ratio = base.player_stamina_ratio
	context.opponent_center_distance = base.opponent_center_distance
	context.recovery_distance = base.recovery_distance

	# AiPointContext-specific derived fields.
	var side_dot: float = (context.ball_position - context.player_position).dot(target_player.basis.x)
	context.ball_side = BallSide.FOREHAND if side_dot > 0.0 else BallSide.BACKHAND
	context.short_ball_opportunity = abs(context.ball_position.z) < GameConstants.SERVICE_LINE_Z

	return context
