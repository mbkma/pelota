## Situation the AI decides a shot in: where the ball is met, how stretched the player is, where
## the opponent stands and the chosen intent and target lane.
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

## The opponent covers the court best a little toward the side the ball is hit from: this share
## of the contact's distance from the middle.
const COVERING_SHARE: float = 0.35
## Distance (m) of the opponent sideways from its covering position from which it counts as out
## of position, and from which fully.
const OUT_OF_POSITION_START: float = 0.8
const OUT_OF_POSITION_FULL: float = 2.8
## Bounce depth (m from the net) from which an incoming ball is short, and from which fully; and
## its pace (m/s off the opponent's racket) from which it is weak, and from which fully. A short
## ball is a chance, a short and weak one a full chance; a serve, always short, is none.
const SHORT_BOUNCE_START: float = 9.0
const SHORT_BOUNCE_FULL: float = 6.5
const WEAK_PACE_START: float = 27.0
const WEAK_PACE_FULL: float = 20.0
## The player reaches the ball from this far (m) away.
const REACH: float = 0.8

var player: Player
var play_style: AiPlayStyle
## Step the ball is met at; null for a serve.
var closest_step: TrajectoryStep
var is_serve: bool = false
var is_second_serve: bool = false

var player_position: Vector3
var ball_position: Vector3
var incoming_ball_speed: float = 0.0
## Share of the time until contact the player needs to get to the ball: near 1 it barely gets
## there.
var stretch: float = 0.0
var player_stamina_ratio: float = 1.0
## Where the opponent stands as the shot is decided
var opponent_position: Vector3
## How far out of position the opponent is, in [0, 1] (see OUT_OF_POSITION_START), and the side
## (sign of x) of the open court away from it; 0 while it is in position.
var opponent_out_of_position: float = 0.0
var open_side: float = 0.0

var ball_side: BallSide = BallSide.FOREHAND
## How much of a chance the incoming ball gives, in [0, 1]: a short ball can be attacked or
## angled away (see SHORT_BOUNCE_START).
var opportunity: float = 0.0
## How much a deep incoming ball pushes the player back, in [0, 1] (see Player.depth_pressure)
var depth_pressure: float = 0.0
var intent: ShotIntent = ShotIntent.NEUTRAL
var target_lane: TargetLane = TargetLane.CROSS
## Whether the shot is a short angle cross court that pulls the opponent out wide
var is_angle: bool = false


## Context for meeting the ball at `step`, or for a serve when `step` is null.
func _init(target_player: Player, step: TrajectoryStep) -> void:
	player = target_player
	play_style = target_player.player_data.play_style
	closest_step = step
	is_serve = step == null
	is_second_serve = is_serve and target_player.session.is_second_serve()

	player_position = target_player.global_position
	ball_position = step.point if step else player_position
	if target_player.ball:
		incoming_ball_speed = target_player.ball.velocity.length()
	player_stamina_ratio = target_player.get_stamina_ratio()
	observe_opponent()

	var side_dot: float = (ball_position - player_position).dot(target_player.basis.x)
	ball_side = BallSide.FOREHAND if side_dot > 0.0 else BallSide.BACKHAND
	if not step:
		return
	var to_ball := Vector3(
		ball_position.x - player_position.x, 0.0, ball_position.z - player_position.z
	)
	var run: Vector3 = to_ball - to_ball.limit_length(REACH)
	stretch = target_player.time_to_reach(player_position + run) / maxf(step.time, 0.001)
	if not step.is_volley_contact():
		var is_return: bool = target_player.is_returning_serve()
		var bounce_depth: float = absf(_bounce_point(target_player.ball).z)
		depth_pressure = Player.depth_pressure(bounce_depth, is_return)
		if is_return:
			return
		var short: float = clampf(
			inverse_lerp(SHORT_BOUNCE_START, SHORT_BOUNCE_FULL, bounce_depth), 0.0, 1.0
		)
		var weak: float = clampf(
			inverse_lerp(WEAK_PACE_START, WEAK_PACE_FULL, incoming_ball_speed), 0.0, 1.0
		)
		opportunity = short * lerpf(0.5, 1.0, weak)


## Looks where the opponent stands now: how far out of position it is and where the open court
## is.
func observe_opponent() -> void:
	opponent_position = player.opponent.global_position
	var off_cover: float = opponent_position.x - ball_position.x * COVERING_SHARE
	opponent_out_of_position = clampf(
		inverse_lerp(OUT_OF_POSITION_START, OUT_OF_POSITION_FULL, absf(off_cover)), 0.0, 1.0
	)
	open_side = -signf(off_cover) if opponent_out_of_position > 0.0 else 0.0


## Where the incoming ball bounces on this side
static func _bounce_point(ball: Ball) -> Vector3:
	for step in ball.predict_trajectory():
		if step.bounces > ball.bounces_since_stroke:
			return step.point
	return ball.last_bounce_position


## Side (sign of x) of the opponent's court a shot into `lane` goes to: cross court goes to the
## other side than the ball is met on, down the line to the same side.
func lane_side(lane: TargetLane) -> float:
	var hit_side: float = signf(ball_position.x) if not is_zero_approx(ball_position.x) else 1.0
	match lane:
		TargetLane.CROSS:
			return -hit_side
		TargetLane.DOWN_THE_LINE:
			return hit_side
	return 0.0


## Whether the stroke is a volley: the ball is taken before it bounces.
func is_volley() -> bool:
	return closest_step != null and closest_step.is_volley_contact()
