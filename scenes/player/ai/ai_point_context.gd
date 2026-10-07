## Situation the AI decides a shot in: where the ball is met, how stretched the player is and
## the chosen intent and target lane.
class_name AiPointContext
extends RefCounted

enum BallSide {
	FOREHAND,
	BACKHAND,
}

enum ShotIntent {
	SAFE,
	NEUTRAL,
	ATTACK,
	SERVE,
}

enum TargetLane {
	CROSS,
	CENTER,
	DOWN_THE_LINE,
}

var player: Player
var play_style: AiPlayStyle
## Step the ball is met at; null for a serve.
var closest_step: TrajectoryStep
var is_serve: bool = false

var player_position: Vector3
var ball_position: Vector3
var incoming_ball_speed: float = 0.0
var player_movement_speed: float = 0.0
var player_stamina_ratio: float = 1.0
## Distance (m) of the opponent from the middle of their baseline
var opponent_center_distance: float = 0.0

var ball_side: BallSide = BallSide.FOREHAND
var short_ball_opportunity: bool = false
var intent: ShotIntent = ShotIntent.NEUTRAL
var target_lane: TargetLane = TargetLane.CROSS


## Context for meeting the ball at `step`, or for a serve when `step` is null.
func _init(target_player: Player, step: TrajectoryStep) -> void:
	player = target_player
	play_style = target_player.player_data.play_style
	closest_step = step
	is_serve = step == null

	player_position = target_player.global_position
	ball_position = step.point if step else player_position
	if target_player.ball:
		incoming_ball_speed = target_player.ball.velocity.length()
	player_movement_speed = Vector2(target_player.velocity.x, target_player.velocity.z).length()
	player_stamina_ratio = target_player.get_stamina_ratio()

	var opponent_baseline_center := Vector3(
		0.0,
		target_player.opponent.global_position.y,
		-signf(player_position.z) * GameConstants.COURT_LENGTH_HALF
	)
	opponent_center_distance = target_player.opponent.global_position.distance_to(
		opponent_baseline_center
	)

	var side_dot: float = (ball_position - player_position).dot(target_player.basis.x)
	ball_side = BallSide.FOREHAND if side_dot > 0.0 else BallSide.BACKHAND
	short_ball_opportunity = absf(ball_position.z) < GameConstants.SERVICE_LINE + 3


## Whether the stroke is a volley: taken close to the net before the ball bounces.
func is_volley() -> bool:
	return closest_step != null and closest_step.is_volley_contact()
