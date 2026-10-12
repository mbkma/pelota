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

## Spread (standard deviation, m) of the landing point of a rally shot from no to full
## precision, across and along the court. In Hawk-Eye tracking of the Australian Open ~15% of
## rally shots miss, 53% of the misses long, 31% wide and 16% into the net (a ball aimed short
## at the same pace flies too low).
const RALLY_ERROR_SPREAD_WIDTH: Vector2 = Vector2(1.8, 0.8)
const RALLY_ERROR_SPREAD_DEPTH: Vector2 = Vector2(2.6, 1.2)
## How much the spread grows (share) with the difficulty of the incoming ball (see
## _difficulty), and its share for a safe and for an attacking shot.
const DIFFICULTY_ERROR_GROWTH: float = 1.5
const SAFE_ERROR_FACTOR: float = 0.8
const ATTACK_ERROR_FACTOR: float = 1.15
## Incoming pace (m/s off the opponent's racket) from which a ball is hard to control, and from
## which fully (Hawk-Eye tracked rally balls leave the racket at ~35 m/s); and the
## stretch (see AiPointContext.stretch) from which getting to it is.
const HARD_PACE: Vector2 = Vector2(32.0, 45.0)
const HARD_STRETCH: Vector2 = Vector2(0.8, 1.4)
## Time (s) until contact from which being stretched makes a ball hard, and from which fully: a
## player who gets to a slow ball (a drop shot) has time to set up for it.
const RUSHED_TIME: Vector2 = Vector2(1.6, 0.9)
## Spread (standard deviation, m) of the landing point of a first and of a second serve, from
## no to full precision. In the tracking data a first serve goes for the lines and goes in ~64%
## of the time; a second serve keeps a margin and misses ~7% of the time.
const FIRST_SERVE_ERROR_SPREAD: Vector2 = Vector2(1.05, 0.7)
const SECOND_SERVE_ERROR_SPREAD: Vector2 = Vector2(1.2, 0.78)
## Serve targets (normalized x: 0 = T, 1 = sideline): down the T, at the body and wide. A first
## serve goes down the T or wide (45% each in the tracking data, 9% at the body), a second serve
## to all three alike (36% T, 35% body, 29% wide), less close to the lines. Their depth (share of
## the service line): a first serve lands ~1.2 m inside the service line, a second ~1.5 m.
## A precise server aims its first serve closer to the lines: from the least to the most precise.
const FIRST_SERVE_T: Vector2 = Vector2(0.2, 0.06)
const FIRST_SERVE_BODY: float = 0.5
const FIRST_SERVE_WIDE: Vector2 = Vector2(0.8, 0.94)
const FIRST_SERVE_T_CHANCE: float = 0.45
const FIRST_SERVE_BODY_CHANCE: float = 0.09
const FIRST_SERVE_DEPTH: float = 0.87
const SECOND_SERVE_T: float = 0.22
const SECOND_SERVE_BODY: float = 0.5
const SECOND_SERVE_WIDE: float = 0.75
const SECOND_SERVE_T_CHANCE: float = 0.36
const SECOND_SERVE_BODY_CHANCE: float = 0.35
const SECOND_SERVE_DEPTH: float = 0.78

## Share of the serve speed (GameConstants.SERVE_SPEED) a second serve keeps (ATP average
## ~95 mph) and the random variation per serve.
const SECOND_SERVE_SPEED_FACTOR: float = 0.8
const SERVE_SPEED_VARIATION: float = 0.05
## Rally speed (m/s) of a groundstroke from the weakest to the best stroke; the play style's
## shot power adds up to STYLE_RALLY_SPEED. With the rally topspin (see _shot_spin) it gives the
## arcs of Hawk-Eye tracked rally balls (Australian Open): ~0.55 m over the cord, peaking at
## ~1.7 m, ~125-130 km/h off the racket.
const RALLY_SPEED: Vector2 = Vector2(31.5, 35.0)
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
## Rally targets (normalized: width, depth) of a safe and a neutral groundstroke, and the width
## and depth range of an attack. With the landing error (see _apply_consistency_error) they
## spread like Hawk-Eye tracked rally balls: half land within 2.3 m of the middle, nine in ten
## within 3.5 m, and half 3.7 m or more inside the baseline.
const SAFE_TARGET: Vector2 = Vector2(0.35, 0.69)
const NEUTRAL_TARGET: Vector2 = Vector2(0.6, 0.76)
const ATTACK_TARGET_WIDTH: float = 0.8
const ATTACK_TARGET_DEPTH: Vector2 = Vector2(0.62, 0.85)
## Short angle cross court (see AiPointContext.is_angle): its target (normalized: width, depth),
## and the share of the rally speed and attack pace and the extra topspin that make it dip in
## short.
const ANGLE_TARGET: Vector2 = Vector2(0.95, 0.6)
const ANGLE_SPEED_FACTOR: float = 0.8
const ANGLE_ATTACK_FACTOR: float = 0.5
const ANGLE_TOPSPIN: float = 0.15


## Stroke of `stroke_type` (see choose_stroke_type) playing the shot planned in `context`.
static func build_stroke(context: AiPointContext, stroke_type: Stroke.StrokeType) -> Stroke:
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

	var lane_sign: float = context.lane_side(context.target_lane)
	if context.is_angle:
		return Vector2(lane_sign * ANGLE_TARGET.x, ANGLE_TARGET.y)
	match context.intent:
		AiPointContext.ShotIntent.SAFE:
			return Vector2(lane_sign * SAFE_TARGET.x, SAFE_TARGET.y)
		AiPointContext.ShotIntent.ATTACK:
			return Vector2(
				lane_sign * ATTACK_TARGET_WIDTH,
				lerpf(ATTACK_TARGET_DEPTH.x, ATTACK_TARGET_DEPTH.y, randf())
			)
	return Vector2(lane_sign * NEUTRAL_TARGET.x, NEUTRAL_TARGET.y)


## Serves go cross court into the service box, down the T, at the body or wide: a first serve
## close to the lines, a second serve with more margin.
static func _serve_target(context: AiPointContext) -> Vector2:
	var box_side: float = -signf(context.player_position.x)
	var roll: float = randf()
	if context.is_second_serve:
		var second_x: float = SECOND_SERVE_WIDE
		if roll < SECOND_SERVE_T_CHANCE:
			second_x = SECOND_SERVE_T
		elif roll < SECOND_SERVE_T_CHANCE + SECOND_SERVE_BODY_CHANCE:
			second_x = SECOND_SERVE_BODY
		return Vector2(box_side * second_x, SECOND_SERVE_DEPTH)
	var precision: float = context.player.stats.serve_accuracy01(context.player_stamina_ratio)
	var x: float = lerpf(FIRST_SERVE_WIDE.x, FIRST_SERVE_WIDE.y, precision)
	if roll < FIRST_SERVE_T_CHANCE:
		x = lerpf(FIRST_SERVE_T.x, FIRST_SERVE_T.y, precision)
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


## Stroke type for the ball in `context`: by the side it is met on, a volley out of the air, a
## safe backhand sometimes sliced.
static func choose_stroke_type(context: AiPointContext) -> Stroke.StrokeType:
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
	if context.is_angle:
		shot_speed *= ANGLE_SPEED_FACTOR
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
	if context.is_angle:
		attack_power *= ANGLE_ATTACK_FACTOR
	return attack_power


static func _shot_spin(
	context: AiPointContext, normalized_x: float, stroke_type: Stroke.StrokeType
) -> Vector3:
	var style_topspin: float = context.play_style.topspin
	var side_sign: float = -1.0 if normalized_x < 0.0 else 1.0

	if stroke_type == Stroke.StrokeType.SERVE:
		# A first serve is hit flat or sliced, a second serve with kick (more topspin).
		var serve_topspin: float = (
			lerpf(0.6, 0.9, style_topspin)
			if context.is_second_serve
			else lerpf(0.2, 0.45, style_topspin)
		)
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
	var intent_spin_bonus: float = 0.2
	match context.intent:
		AiPointContext.ShotIntent.SAFE:
			intent_spin_bonus = 0.45
		AiPointContext.ShotIntent.ATTACK:
			intent_spin_bonus = 0.08
	var topspin: float = lerpf(0.4, 0.68, topspin_skill) + style_topspin * intent_spin_bonus
	if context.is_angle:
		topspin += ANGLE_TOPSPIN
	return Vector3(0.0, clampf(topspin, -1.0, 1.0), 0.0)


## Misses the intended target by a normally distributed offset: its spread is set by the
## player's precision (serve accuracy, or shot control with return and volley skill) and play
## style, and for a rally shot by the intent and how hard the incoming ball is.
static func _apply_consistency_error(intended_target: Vector3, context: AiPointContext) -> Vector3:
	var stats: PlayerRuntimeStats = context.player.stats
	var consistency: float = lerpf(1.2, 0.8, context.play_style.consistency)
	var offset: Vector2
	if context.is_serve:
		var spread_range: Vector2 = (
			SECOND_SERVE_ERROR_SPREAD if context.is_second_serve else FIRST_SERVE_ERROR_SPREAD
		)
		var precision: float = stats.serve_accuracy01(context.player_stamina_ratio)
		var spread: float = lerpf(spread_range.x, spread_range.y, precision) * consistency
		offset = Vector2(randfn(0.0, spread), randfn(0.0, spread))
	else:
		var precision: float = stats.rally_precision01(
			context.player_stamina_ratio, context.player.is_returning_serve(), context.is_volley()
		)
		var factor: float = consistency * (1.0 + DIFFICULTY_ERROR_GROWTH * _difficulty(context))
		match context.intent:
			AiPointContext.ShotIntent.SAFE:
				factor *= SAFE_ERROR_FACTOR
			AiPointContext.ShotIntent.ATTACK:
				factor *= ATTACK_ERROR_FACTOR
		offset = Vector2(
			randfn(0.0, lerpf(RALLY_ERROR_SPREAD_WIDTH.x, RALLY_ERROR_SPREAD_WIDTH.y, precision)),
			randfn(0.0, lerpf(RALLY_ERROR_SPREAD_DEPTH.x, RALLY_ERROR_SPREAD_DEPTH.y, precision))
		)
		offset *= factor
	return intended_target + Vector3(offset.x, 0.0, offset.y)


## How hard the incoming ball is to control, in [0, 1]: by how stretched the player is when the
## ball comes quickly, how far a deep ball pushes it back and the ball's pace; the hardest of
## these counts.
static func _difficulty(context: AiPointContext) -> float:
	var pace: float = clampf(
		inverse_lerp(HARD_PACE.x, HARD_PACE.y, context.incoming_ball_speed), 0.0, 1.0
	)
	var rushed: float = clampf(
		inverse_lerp(RUSHED_TIME.x, RUSHED_TIME.y, context.closest_step.time), 0.0, 1.0
	)
	var stretch: float = (
		clampf(inverse_lerp(HARD_STRETCH.x, HARD_STRETCH.y, context.stretch), 0.0, 1.0) * rushed
	)
	return maxf(maxf(stretch, context.depth_pressure), pace)


static func _is_drop_volley(stroke_type: Stroke.StrokeType) -> bool:
	return (
		stroke_type == Stroke.StrokeType.FOREHAND_DROP_VOLLEY
		or stroke_type == Stroke.StrokeType.BACKHAND_DROP_VOLLEY
	)
