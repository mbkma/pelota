## Turns a planned AI shot (intent and target lane) into a stroke: type, target, pace and spin.
class_name ShotExecutor
extends RefCounted

## Chance that a volley below the net cord which is not an attack is played as a drop volley (a
## higher ball is put away instead).
const DROP_VOLLEY_CHANCE: float = 0.25
## Normalized depth (0 = net, 1 = baseline) of drop volley targets.
const DROP_VOLLEY_DEPTH: float = 0.2
## Volleys go toward the open court, this wide (normalized). A high ball is put away short (an
## attacking volley into a sharp angle), a low one goes deep (see GameConstants).
const VOLLEY_WIDTH: float = 0.8
const VOLLEY_DEPTH_NEUTRAL_HIGH_BALL: float = 7.0
## Chance that a safe backhand is played as a slice.
const SAFE_SLICE_CHANCE: float = 0.45

## Largest landing error (m) of a rally shot for a player with no precision.
const AI_RALLY_ERROR_RADIUS: float = 1.8
## Landing error radius (m) of a first and of a second serve, from no to full precision. A
## first serve goes for the lines and goes in ~60-65% of the time; a second serve keeps a safe
## margin (~90% in).
const FIRST_SERVE_ERROR_RADIUS: Vector2 = Vector2(2.0, 1.35)
const SECOND_SERVE_ERROR_RADIUS: Vector2 = Vector2(1.6, 1.0)
## First serve targets (normalized x: 0 = T, 1 = sideline) with their chances: down the T, at
## the body and wide; and their depth (share of the service line). A second serve goes to the
## body, safely inside the lines.
const FIRST_SERVE_T: float = 0.12
const FIRST_SERVE_BODY: float = 0.5
const FIRST_SERVE_WIDE: float = 0.88
const FIRST_SERVE_T_CHANCE: float = 0.4
const FIRST_SERVE_BODY_CHANCE: float = 0.2
const FIRST_SERVE_DEPTH: float = 0.91
const SECOND_SERVE_X: float = 0.45
const SECOND_SERVE_DEPTH: float = 0.88

## Share of the serve speed (GameConstants.SERVE_SPEED) a second serve keeps (ATP average
## ~95 mph) and the random variation per serve.
const SECOND_SERVE_SPEED_FACTOR: float = 0.8
const SERVE_SPEED_VARIATION: float = 0.05
## Rally speed (m/s) of a groundstroke from the weakest to the best stroke (ATP averages:
## forehand ~115 km/h, backhand ~105 km/h); the play style's shot power adds up to
## STYLE_RALLY_SPEED.
const RALLY_SPEED: Vector2 = Vector2(27.0, 31.5)
const STYLE_RALLY_SPEED: float = 1.5
## Share of the rally speed of a safe shot and of a slice.
const SAFE_SPEED_FACTOR: float = 0.92
const SLICE_SPEED_FACTOR: float = 0.72
## Attack pace (m/s) of a neutral and of an attacking groundstroke from the weakest to the best
## stroke; it only comes through when the ball is met in position and set (see Player).
const NEUTRAL_ATTACK: Vector2 = Vector2(3.0, 5.0)
const ATTACK_ATTACK: Vector2 = Vector2(9.0, 13.0)
## Share of the attack pace a slice keeps.
const SLICE_ATTACK_FACTOR: float = 0.3


static func build_stroke(context: AiPointContext) -> Stroke:
	var stroke_type: Stroke.StrokeType = _determine_stroke_type(context)
	var normalized_target: Vector2 = _normalized_target(context)
	if _is_drop_volley(stroke_type):
		normalized_target.y = DROP_VOLLEY_DEPTH

	var stroke := Stroke.new()
	stroke.stroke_type = stroke_type
	stroke.intended_stroke_target = _to_world_target(normalized_target, context)
	stroke.stroke_target = _apply_consistency_error(stroke.intended_stroke_target, context)
	stroke.intended_stroke_power = _shot_speed(context, stroke_type)
	stroke.stroke_power = stroke.intended_stroke_power
	stroke.attack_power = _attack_power(context, stroke_type)
	stroke.stroke_spin = _shot_spin(context, normalized_target.x, stroke_type)
	stroke.stroke_intent = context.intent
	stroke.step = context.closest_step
	return stroke


## Target in the opponent's court: x in [-1, 1] across the court, y in [0, 1] from the net to
## the baseline (to the service line for a serve).
static func _normalized_target(context: AiPointContext) -> Vector2:
	if context.is_serve:
		return _serve_target(context)
	if context.is_volley():
		return _volley_target(context)

	var lane_sign: float = 0.0
	match context.target_lane:
		AiPointContext.TargetLane.CROSS:
			lane_sign = -1.0
		AiPointContext.TargetLane.DOWN_THE_LINE:
			lane_sign = 1.0

	match context.intent:
		AiPointContext.ShotIntent.SAFE:
			return Vector2(lane_sign * 0.38, 0.75)
		AiPointContext.ShotIntent.ATTACK:
			return Vector2(lane_sign * 0.9, maxf(0.6, randf()))
	return Vector2(lane_sign * 0.75, 0.85)


## Serves go cross court into the service box: a first serve down the T, at the body or wide
## near the lines, a second serve safely to the body.
static func _serve_target(context: AiPointContext) -> Vector2:
	var box_side: float = -signf(context.player_position.x)
	if context.is_second_serve:
		return Vector2(box_side * SECOND_SERVE_X, SECOND_SERVE_DEPTH)
	var roll: float = randf()
	var x: float = FIRST_SERVE_WIDE
	if roll < FIRST_SERVE_T_CHANCE:
		x = FIRST_SERVE_T
	elif roll < FIRST_SERVE_T_CHANCE + FIRST_SERVE_BODY_CHANCE:
		x = FIRST_SERVE_BODY
	return Vector2(box_side * x, FIRST_SERVE_DEPTH)


## Volleys are angled away from the opponent into the open court.
static func _volley_target(context: AiPointContext) -> Vector2:
	var opponent_x: float = context.player.opponent.global_position.x
	var open_side: float = -signf(opponent_x) if absf(opponent_x) > 0.3 else signf(randf() - 0.5)
	var high_ball_depth: float = (
		GameConstants.VOLLEY_DEPTH_MIN
		if context.intent == AiPointContext.ShotIntent.ATTACK
		else VOLLEY_DEPTH_NEUTRAL_HIGH_BALL
	)
	var put_away: float = Player.volley_put_away_share(context.ball_position.y)
	var depth: float = lerpf(GameConstants.VOLLEY_DEPTH_LOW_BALL, high_ball_depth, put_away)
	return Vector2(open_side * VOLLEY_WIDTH, depth / GameConstants.COURT_LENGTH_HALF)


static func _to_world_target(normalized_target: Vector2, context: AiPointContext) -> Vector3:
	var length: float = (
		GameConstants.SERVICE_LINE if context.is_serve else GameConstants.COURT_LENGTH_HALF
	)
	var opponent_side: float = -1.0 if context.player_position.z >= 0.0 else 1.0
	return Vector3(
		clampf(normalized_target.x, -1.0, 1.0) * GameConstants.COURT_WIDTH_HALF,
		context.player_position.y,
		clampf(normalized_target.y, 0.0, 1.0) * length * opponent_side
	)


static func _determine_stroke_type(context: AiPointContext) -> Stroke.StrokeType:
	if context.is_serve:
		return Stroke.StrokeType.SERVE

	var is_forehand: bool = context.ball_side == AiPointContext.BallSide.FOREHAND
	if context.is_volley():
		var below_net: bool = context.ball_position.y < Ball.NET_CENTER_HEIGHT
		var not_attack: bool = context.intent != AiPointContext.ShotIntent.ATTACK
		if below_net and not_attack and randf() < DROP_VOLLEY_CHANCE:
			return (
				Stroke.StrokeType.FOREHAND_DROP_VOLLEY
				if is_forehand
				else Stroke.StrokeType.BACKHAND_DROP_VOLLEY
			)
		return (
			Stroke.StrokeType.FOREHAND_VOLLEY if is_forehand else Stroke.StrokeType.BACKHAND_VOLLEY
		)

	if is_forehand:
		return Stroke.StrokeType.FOREHAND
	if context.intent == AiPointContext.ShotIntent.SAFE and randf() < SAFE_SLICE_CHANCE:
		return Stroke.StrokeType.BACKHAND_SLICE
	return Stroke.StrokeType.BACKHAND


## Rally speed of the stroke (serve speed for a serve), before any attack pace.
static func _shot_speed(context: AiPointContext, stroke_type: Stroke.StrokeType) -> float:
	var stats: PlayerRuntimeStats = context.player.stats
	var style_power: float = context.play_style.shot_power
	if context.is_serve:
		var serve_speed: float = lerpf(
			GameConstants.SERVE_SPEED.x, GameConstants.SERVE_SPEED.y, stats.serve_power01()
		)
		serve_speed *= lerpf(0.94, 1.0, style_power)
		serve_speed *= lerpf(0.9, 1.0, context.player_stamina_ratio)
		serve_speed *= 1.0 + randf_range(-SERVE_SPEED_VARIATION, SERVE_SPEED_VARIATION)
		if context.is_second_serve:
			serve_speed *= SECOND_SERVE_SPEED_FACTOR
		return serve_speed

	# A volley's own pace; the incoming pace it redirects is added at contact (see Player).
	if _is_drop_volley(stroke_type):
		return lerpf(
			GameConstants.DROP_VOLLEY_SPEED.x, GameConstants.DROP_VOLLEY_SPEED.y, stats.volley01()
		)
	if context.is_volley():
		return lerpf(
			GameConstants.VOLLEY_PUNCH_SPEED.x, GameConstants.VOLLEY_PUNCH_SPEED.y, stats.volley01()
		)

	var side_quality: float = stats.shot_side_skill01(
		context.ball_side == AiPointContext.BallSide.BACKHAND
	)
	var shot_speed: float = lerpf(RALLY_SPEED.x, RALLY_SPEED.y, side_quality)
	shot_speed += style_power * STYLE_RALLY_SPEED
	if context.intent == AiPointContext.ShotIntent.SAFE:
		shot_speed *= SAFE_SPEED_FACTOR
	shot_speed *= lerpf(0.86, 1.0, context.player_stamina_ratio)
	if stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		shot_speed *= SLICE_SPEED_FACTOR
	return shot_speed


## Attack pace of the stroke by intent: none for safe shots, touch shots and serves.
static func _attack_power(context: AiPointContext, stroke_type: Stroke.StrokeType) -> float:
	if context.is_serve or context.intent == AiPointContext.ShotIntent.SAFE:
		return 0.0
	if _is_drop_volley(stroke_type):
		return 0.0
	var style_power: float = context.play_style.shot_power
	# A high volley is put away; the contact height decides how much of it comes through.
	if context.is_volley():
		return GameConstants.VOLLEY_PUT_AWAY_PACE * lerpf(0.7, 1.0, style_power)
	var is_attack: bool = context.intent == AiPointContext.ShotIntent.ATTACK

	var side_quality: float = context.player.stats.shot_side_skill01(
		context.ball_side == AiPointContext.BallSide.BACKHAND
	)
	var attack_power: float = (
		lerpf(ATTACK_ATTACK.x, ATTACK_ATTACK.y, side_quality) * lerpf(0.7, 1.0, style_power)
		if is_attack
		else lerpf(NEUTRAL_ATTACK.x, NEUTRAL_ATTACK.y, side_quality) * style_power
	)
	attack_power *= lerpf(0.86, 1.0, context.player_stamina_ratio)
	if stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		attack_power *= SLICE_ATTACK_FACTOR
	return attack_power


static func _shot_spin(
	context: AiPointContext, normalized_x: float, stroke_type: Stroke.StrokeType
) -> Vector3:
	var style_topspin: float = context.play_style.topspin
	var side_sign: float = -1.0 if normalized_x < 0.0 else 1.0

	if stroke_type == Stroke.StrokeType.SERVE:
		var serve_topspin: float = lerpf(0.55, 0.9, style_topspin)
		var serve_side: float = side_sign * lerpf(0.08, 0.3, context.play_style.aggression)
		return Vector3(serve_side, serve_topspin, 0.0)
	if stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		return Vector3(-0.22 * side_sign, -0.86, 0.0)
	if _is_drop_volley(stroke_type):
		return GameConstants.DROP_VOLLEY_SPIN
	if context.is_volley():
		return GameConstants.VOLLEY_SPIN

	var topspin_skill: float = context.player.stats.spin_control01(
		stroke_type, context.player_stamina_ratio
	)
	var intent_spin_bonus: float = 0.3
	match context.intent:
		AiPointContext.ShotIntent.SAFE:
			intent_spin_bonus = 0.6
		AiPointContext.ShotIntent.ATTACK:
			intent_spin_bonus = 0.12
	var topspin: float = lerpf(0.46, 0.88, topspin_skill) + style_topspin * intent_spin_bonus
	return Vector3(0.0, clampf(topspin, -1.0, 1.0), 0.0)


## Misses the intended target by a random offset inside a radius set by the player's
## precision (serve accuracy, or shot control with return and volley skill) and play style.
static func _apply_consistency_error(intended_target: Vector3, context: AiPointContext) -> Vector3:
	var stats: PlayerRuntimeStats = context.player.stats
	var precision: float
	var radius_range := Vector2(AI_RALLY_ERROR_RADIUS, 0.15)
	if context.is_serve:
		precision = stats.serve_accuracy01(context.player_stamina_ratio)
		radius_range = (
			SECOND_SERVE_ERROR_RADIUS if context.is_second_serve else FIRST_SERVE_ERROR_RADIUS
		)
	else:
		precision = stats.rally_precision01(
			context.player_stamina_ratio, context.player.is_returning_serve(), context.is_volley()
		)
	var error_radius: float = (
		lerpf(radius_range.x, radius_range.y, precision)
		* lerpf(1.2, 0.8, context.play_style.consistency)
	)
	var offset: Vector2 = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * error_radius
	return intended_target + Vector3(offset.x, 0.0, offset.y)


static func _is_drop_volley(stroke_type: Stroke.StrokeType) -> bool:
	return (
		stroke_type == Stroke.StrokeType.FOREHAND_DROP_VOLLEY
		or stroke_type == Stroke.StrokeType.BACKHAND_DROP_VOLLEY
	)
