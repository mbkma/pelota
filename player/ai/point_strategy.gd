class_name PointStrategy
extends Resource

## Play style resource that configures dynamic shot behavior.
@export var play_style: AiPlayStyle

var _player: Player
var _execution := ShotExecution.new()
var _targeting := NormalizedCourtTargeting.new()


func setup(target_player: Player) -> void:
	_player = target_player


func validate_configuration() -> bool:
	if not play_style:
		push_error("PointStrategy.validate_configuration: play_style is not configured")
		return false

	return true


func compute_next_stroke(closest_step: TrajectoryStep) -> Stroke:
	if not _player:
		push_error("PointStrategy.compute_next_stroke: setup(player) must be called before use")
		return null
	if not play_style:
		push_error("PointStrategy.compute_next_stroke: play_style is not configured")
		return null

	var context := AiPointContext.from_step(_player, closest_step, false)
	var intent := choose_tactical_intent(context)
	var risk := _compute_shot_risk(context, intent)
	context.selected_intent = intent
	context.shot_risk = risk
	context.play_style = play_style
	
	var intent_name: String = AiPointContext.ShotIntent.keys()[intent] if intent < AiPointContext.ShotIntent.size() else "UNKNOWN"
	DebugLogger.log(_player, "Intent: %s | Risk: %.2f | Ball: %.2f m/s@%.2fm | Player speed: %.2f | Opp dist: %.2f" % [
		intent_name,
		risk,
		context.incoming_ball_speed,
		context.ball_height,
		context.player_movement_speed,
		context.opponent_center_distance
	])
	
	return _execution.call("build_stroke", context, _targeting) as Stroke


func compute_serve() -> Stroke:
	if not _player:
		push_error("PointStrategy.compute_serve: setup(player) must be called before use")
		return null
	if not play_style:
		push_error("PointStrategy.compute_serve: play_style is not configured")
		return null

	var context := AiPointContext.from_step(_player, null, true)
	var intent := AiPointContext.ShotIntent.SERVE
	var risk := _compute_shot_risk(context, intent)
	context.selected_intent = intent
	context.shot_risk = risk
	context.play_style = play_style
	
	DebugLogger.log(_player, "Serve synthesis | Risk: %.2f | Style: %s (agg=%.2f risk_tol=%.2f pace_pref=%.2f)" % [
		risk,
		play_style.style_name,
		play_style.aggression,
		play_style.risk_tolerance,
		play_style.preferred_rally_pace
	])
	
	return _execution.call("build_stroke", context, _targeting) as Stroke


func choose_tactical_intent(context: AiPointContext) -> AiPointContext.ShotIntent:
	if context.is_serve:
		return AiPointContext.ShotIntent.SERVE

	if context.short_ball_opportunity and play_style.aggression >= 0.45:
		return AiPointContext.ShotIntent.ATTACK

	if context.player_movement_speed > 4.5 and context.incoming_ball_speed > 17.0:
		return AiPointContext.ShotIntent.DEFEND

	if play_style.net_frequency > 0.7 and context.ball_height > 0.5 and context.ball_height < 1.4:
		if randf() < play_style.net_frequency:
			return AiPointContext.ShotIntent.APPROACH_NET

	if context.opponent_center_distance > 2.4 and play_style.risk_tolerance > 0.55:
		return AiPointContext.ShotIntent.ATTACK

	return AiPointContext.ShotIntent.NEUTRAL


func _compute_shot_risk(context: AiPointContext, intent: AiPointContext.ShotIntent) -> float:
	var risk: float = play_style.risk_tolerance

	if intent == AiPointContext.ShotIntent.ATTACK:
		risk += 0.2 * play_style.aggression
	if intent == AiPointContext.ShotIntent.DEFEND:
		risk -= 0.18
	if intent == AiPointContext.ShotIntent.APPROACH_NET:
		risk += 0.08

	if context.short_ball_opportunity:
		risk += 0.12

	var incoming_pressure: float = clampf(inverse_lerp(8.0, 32.0, context.incoming_ball_speed), 0.0, 1.0)
	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	var pressure: float = maxf(incoming_pressure, movement_pressure)

	# Under pressure, bias toward lower-risk execution windows.
	risk = lerpf(risk, risk * 0.72, pressure)
	return clampf(risk, 0.05, 0.95)
