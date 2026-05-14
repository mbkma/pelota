class_name AiPointContext
extends RefCounted

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

var player: Player
var opponent: Player
var closest_step: TrajectoryStep
var is_serve: bool = false

var player_position: Vector3 = Vector3.ZERO
var opponent_position: Vector3 = Vector3.ZERO
var ball_position: Vector3 = Vector3.ZERO

var incoming_ball_speed: float = 0.0
var ball_height: float = 0.0
var player_movement_speed: float = 0.0
var opponent_center_distance: float = 0.0
var recovery_distance: float = 0.0

var short_ball_opportunity: bool = false
var ball_side: BallSide = BallSide.FOREHAND
var selected_intent: ShotIntent = ShotIntent.NEUTRAL
var shot_risk: float = 0.5
var play_style: AiPlayStyle


static func from_step(target_player: Player, step: TrajectoryStep, serve: bool = false) -> AiPointContext:
	var context := AiPointContext.new()
	context.player = target_player
	context.opponent = target_player.opponent
	context.closest_step = step
	context.is_serve = serve

	context.player_position = target_player.global_position
	context.opponent_position = target_player.opponent.global_position if target_player.opponent else Vector3.ZERO
	context.ball_position = step.point if step else target_player.global_position

	if target_player.ball:
		context.incoming_ball_speed = target_player.ball.velocity.length()
	context.ball_height = context.ball_position.y
	context.player_movement_speed = Vector2(target_player.velocity.x, target_player.velocity.z).length()

	var side_dot: float = (context.ball_position - context.player_position).dot(target_player.basis.x)
	context.ball_side = BallSide.FOREHAND if side_dot > 0.0 else BallSide.BACKHAND

	context.short_ball_opportunity = abs(context.ball_position.z) < GameConstants.SERVICE_LINE_Z

	if target_player.opponent:
		var opponent_recovery := Vector3(0.0, target_player.opponent.global_position.y, -sign(target_player.global_position.z) * GameConstants.COURT_LENGTH_HALF)
		context.opponent_center_distance = target_player.opponent.global_position.distance_to(opponent_recovery)

	var player_recovery := Vector3(0.0, target_player.global_position.y, sign(target_player.global_position.z) * GameConstants.COURT_LENGTH_HALF)
	context.recovery_distance = target_player.global_position.distance_to(player_recovery)

	return context
