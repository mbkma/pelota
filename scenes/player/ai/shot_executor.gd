class_name ShotExecutor
extends RefCounted

## Chance that a volley which is not an attack is played as a drop volley.
const DROP_VOLLEY_CHANCE: float = 0.25
## Normalized depth (0 = net, 1 = baseline) of drop volley targets.
const DROP_VOLLEY_DEPTH: float = 0.2

## Largest landing error (m) of a rally shot and a serve, for a player with no precision.
const AI_RALLY_ERROR_RADIUS: float = 1.8
const AI_SERVE_ERROR_RADIUS: float = 0.9

## First serve speed (m/s) from the weakest to the strongest server (169-209 km/h; ATP average
## first serve ~186 km/h), the share a second serve keeps (ATP average ~152 km/h) and the
## random variation per serve.
const SERVE_SPEED: Vector2 = Vector2(47.0, 58.0)
const SECOND_SERVE_SPEED_FACTOR: float = 0.82
const SERVE_SPEED_VARIATION: float = 0.04
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
## Volley and drop volley speed (m/s) by volley skill, and the attack pace of an attacking volley.
const VOLLEY_SPEED: Vector2 = Vector2(17.0, 22.0)
const DROP_VOLLEY_SPEED: Vector2 = Vector2(6.0, 10.0)
const VOLLEY_ATTACK: float = 5.0

## When true, intended shot equals executed shot (no consistency error)
var perfect_accuracy: bool = false


func _stats(context: AiPointContext) -> PlayerRuntimeStats:
	assert(context != null, "ShotExecutor._stats: context is required")
	assert(context.player != null, "ShotExecutor._stats: context.player is required")
	assert(context.player.stats != null, "ShotExecutor._stats: player.stats is required")
	return context.player.stats


func build_stroke(context: AiPointContext, targeting: NormalizedCourtTargeting) -> Stroke:
	if not context or not targeting:
		return null

	var play_style: AiPlayStyle = context.play_style
	var intent: AiPointContext.ShotIntent = context.selected_intent
	var lane: AiPointContext.TargetLane = context.selected_target_lane
	var stroke_type: Stroke.StrokeType = _determine_stroke_type(context, intent)
	var normalized_target: Vector2 = _build_normalized_target(context, play_style, intent, lane)
	if (
		stroke_type == Stroke.StrokeType.FOREHAND_DROP_VOLLEY
		or stroke_type == Stroke.StrokeType.BACKHAND_DROP_VOLLEY
	):
		normalized_target.y = DROP_VOLLEY_DEPTH
	var intended_world_target: Vector3 = targeting.to_world_target(
		normalized_target, context.player_position, context.is_serve
	)
	var actual_target: Vector3 = (
		intended_world_target
		if perfect_accuracy
		else _apply_consistency_error(intended_world_target, context, play_style)
	)
	var intended_power: float = _compute_shot_speed(context, play_style, intent, stroke_type)
	var attack_power: float = _compute_attack_power(context, play_style, intent, stroke_type)

	var stroke := Stroke.new()
	stroke.stroke_type = stroke_type
	stroke.intended_stroke_target = intended_world_target
	stroke.stroke_target = actual_target
	stroke.intended_stroke_power = intended_power
	stroke.stroke_power = intended_power
	stroke.attack_power = attack_power
	stroke.stroke_spin = _compute_shot_spin(
		context, play_style, intent, normalized_target.x, stroke_type
	)
	stroke.stroke_intent = intent
	stroke.step = context.closest_step
	return stroke


func _build_normalized_target(
	context: AiPointContext,
	_play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	lane: AiPointContext.TargetLane
) -> Vector2:
	if context.is_serve:
		var serve_side_sign: float = sign(context.player.position.x)
		return Vector2(-serve_side_sign * 0.5, 0.9)

	var lane_sign: float = 0.0
	match lane:
		AiPointContext.TargetLane.CROSS:
			lane_sign = -1.0
		AiPointContext.TargetLane.DOWN_THE_LINE:
			lane_sign = 1.0
		_:
			lane_sign = 0.0

	var lateral_abs: float = 0.75
	var depth: float = 0.8
	match intent:
		AiPointContext.ShotIntent.SAFE:
			lateral_abs = 0.38
			depth = 0.75
		AiPointContext.ShotIntent.NEUTRAL:
			lateral_abs = 0.75
			depth = 0.8
		AiPointContext.ShotIntent.ATTACK:
			lateral_abs = 0.9
			depth = maxf(0.6, randf())
		_:
			pass

	#if context.short_ball_opportunity and intent == AiPointContext.ShotIntent.ATTACK:
	#depth = minf(depth, 0.7)

	#var court_bias: float = play_style.court_position if play_style else 0.0
	#depth = clampf(depth + (court_bias * 0.22), -1.0, 1.0)

	return Vector2(clampf(lane_sign * lateral_abs, -1.0, 1.0), depth)


func _determine_stroke_type(
	context: AiPointContext, intent: AiPointContext.ShotIntent
) -> Stroke.StrokeType:
	if context.is_serve:
		return Stroke.StrokeType.SERVE

	var is_forehand: bool = context.ball_side == AiPointContext.BallSide.FOREHAND
	if _is_volley(context):
		if intent != AiPointContext.ShotIntent.ATTACK and randf() < DROP_VOLLEY_CHANCE:
			return (
				Stroke.StrokeType.FOREHAND_DROP_VOLLEY
				if is_forehand
				else Stroke.StrokeType.BACKHAND_DROP_VOLLEY
			)
		return (
			Stroke.StrokeType.FOREHAND_VOLLEY if is_forehand else Stroke.StrokeType.BACKHAND_VOLLEY
		)

	if context.ball_side == AiPointContext.BallSide.BACKHAND:
		if intent == AiPointContext.ShotIntent.SAFE and randf() < 0.45:
			return Stroke.StrokeType.BACKHAND_SLICE
		return Stroke.StrokeType.BACKHAND

	return Stroke.StrokeType.FOREHAND


## Rally speed of the stroke (serve speed for a serve), before any attack pace.
func _compute_shot_speed(
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	stroke_type: Stroke.StrokeType
) -> float:
	var stats = _stats(context)
	var style_power: float = play_style.shot_power if play_style else 0.5
	if context.is_serve:
		var serve_speed: float = lerpf(SERVE_SPEED.x, SERVE_SPEED.y, stats.serve_power01())
		serve_speed *= lerpf(0.94, 1.0, style_power)
		serve_speed *= lerpf(0.9, 1.0, context.player_stamina_ratio)
		serve_speed *= 1.0 + randf_range(-SERVE_SPEED_VARIATION, SERVE_SPEED_VARIATION)
		var match_manager: MatchManager = context.player.match_manager
		if match_manager and match_manager.current_state == MatchManager.MatchState.SECOND_SERVE:
			serve_speed *= SECOND_SERVE_SPEED_FACTOR
		return serve_speed

	match stroke_type:
		Stroke.StrokeType.FOREHAND_VOLLEY, Stroke.StrokeType.BACKHAND_VOLLEY:
			return lerpf(VOLLEY_SPEED.x, VOLLEY_SPEED.y, stats.volley01())
		Stroke.StrokeType.FOREHAND_DROP_VOLLEY, Stroke.StrokeType.BACKHAND_DROP_VOLLEY:
			return lerpf(DROP_VOLLEY_SPEED.x, DROP_VOLLEY_SPEED.y, stats.volley01())

	var side_quality: float = stats.shot_side_skill01(
		context.ball_side == AiPointContext.BallSide.BACKHAND
	)
	var shot_speed: float = lerpf(RALLY_SPEED.x, RALLY_SPEED.y, side_quality)
	shot_speed += style_power * STYLE_RALLY_SPEED
	if intent == AiPointContext.ShotIntent.SAFE:
		shot_speed *= SAFE_SPEED_FACTOR
	shot_speed *= lerpf(0.86, 1.0, context.player_stamina_ratio)
	if stroke_type == Stroke.StrokeType.BACKHAND_SLICE:
		shot_speed *= SLICE_SPEED_FACTOR
	return shot_speed


## Attack pace of the stroke by intent: none for safe shots, touch shots and serves.
func _compute_attack_power(
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	stroke_type: Stroke.StrokeType
) -> float:
	if context.is_serve or intent == AiPointContext.ShotIntent.SAFE:
		return 0.0
	var style_power: float = play_style.shot_power if play_style else 0.5
	var is_attack: bool = intent == AiPointContext.ShotIntent.ATTACK
	match stroke_type:
		Stroke.StrokeType.FOREHAND_VOLLEY, Stroke.StrokeType.BACKHAND_VOLLEY:
			return VOLLEY_ATTACK * style_power if is_attack else 0.0
		Stroke.StrokeType.FOREHAND_DROP_VOLLEY, Stroke.StrokeType.BACKHAND_DROP_VOLLEY:
			return 0.0

	var stats = _stats(context)
	var side_quality: float = stats.shot_side_skill01(
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


func _compute_shot_spin(
	context: AiPointContext,
	play_style: AiPlayStyle,
	intent: AiPointContext.ShotIntent,
	normalized_x: float,
	stroke_type: Stroke.StrokeType
) -> Vector3:
	var stats = _stats(context)
	var topspin_skill: float = stats.spin_control01(stroke_type, context.player_stamina_ratio)
	var style_topspin: float = play_style.topspin if play_style else 0.5
	var style_aggression: float = play_style.aggression if play_style else 0.5
	var side_sign: float = sign(normalized_x)
	if side_sign == 0.0:
		side_sign = 1.0

	match stroke_type:
		Stroke.StrokeType.BACKHAND_SLICE:
			return Vector3(-0.22 * side_sign, -0.86, 0.0)
		Stroke.StrokeType.FOREHAND_VOLLEY, Stroke.StrokeType.BACKHAND_VOLLEY:
			return GameConstants.VOLLEY_SPIN
		Stroke.StrokeType.FOREHAND_DROP_VOLLEY, Stroke.StrokeType.BACKHAND_DROP_VOLLEY:
			return GameConstants.DROP_VOLLEY_SPIN
	if stroke_type == Stroke.StrokeType.SERVE:
		var serve_topspin: float = lerpf(0.55, 0.9, style_topspin)
		var serve_side: float = side_sign * lerpf(0.08, 0.3, style_aggression)
		return Vector3(serve_side, serve_topspin, 0.0)

	var base_topspin: float = lerpf(0.46, 0.88, topspin_skill)
	var intent_spin_bonus: float = 0.3
	match intent:
		AiPointContext.ShotIntent.SAFE:
			intent_spin_bonus = 0.6
		AiPointContext.ShotIntent.NEUTRAL:
			intent_spin_bonus = 0.3
		AiPointContext.ShotIntent.ATTACK:
			intent_spin_bonus = 0.12
		_:
			pass

	var topspin_value: float = clampf(base_topspin + (style_topspin * intent_spin_bonus), -1.0, 1.0)
	return Vector3(0, topspin_value, 0.0)


## Misses the intended target by a random offset inside a radius set by the player's
## precision (serve accuracy, or shot control with return and volley skill) and play style.
func _apply_consistency_error(
	intended_target: Vector3, context: AiPointContext, play_style: AiPlayStyle
) -> Vector3:
	var stats: PlayerRuntimeStats = _stats(context)
	var precision: float
	var max_radius: float = AI_RALLY_ERROR_RADIUS
	if context.is_serve:
		precision = stats.serve_accuracy01(context.player_stamina_ratio)
		max_radius = AI_SERVE_ERROR_RADIUS
	else:
		precision = stats.rally_precision01(
			context.player_stamina_ratio, context.player.is_returning_serve(), _is_volley(context)
		)
	var consistency: float = play_style.consistency if play_style else 0.5
	var error_radius: float = lerpf(max_radius, 0.15, precision) * lerpf(1.2, 0.8, consistency)
	var offset: Vector2 = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * error_radius
	return intended_target + Vector3(offset.x, 0.0, offset.y)


## Whether the stroke is a volley: taken close to the net before the ball bounces.
func _is_volley(context: AiPointContext) -> bool:
	return context.closest_step != null and context.closest_step.is_volley_contact()
