class_name PointStrategy
extends Resource

## Play style resource that configures dynamic shot behavior.
@export var play_style: AiPlayStyle

var _player: Player
var _execution := ShotExecution.new()
var _targeting := NormalizedCourtTargeting.new()


func _stats():
	assert(_player != null, "PointStrategy._stats: setup(player) must be called before use")
	assert(_player.stats != null, "PointStrategy._stats: player.stats is required")
	return _player.stats


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
	
	var stats = _stats()
	var intent_name: String = AiPointContext.ShotIntent.keys()[intent] if intent < AiPointContext.ShotIntent.size() else "UNKNOWN"
	DebugLogger.log(_player, "Intent: %s | Risk: %.2f | Stamina: %.2f | Ball: %.2f m/s@%.2fm | Player speed: %.2f | Opp dist: %.2f | agg=%.2f net=%.2f def=%.2f ant=%.2f" % [
		intent_name,
		risk,
		context.player_stamina_ratio,
		context.incoming_ball_speed,
		context.ball_height,
		context.player_movement_speed,
		context.opponent_center_distance,
		stats.tactical_aggression01(),
		stats.tactical_net_play01(),
		stats.tactical_defense01(),
		stats.anticipation01()
	])
	
	return _execution.build_stroke(context, _targeting)


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
	
	var stats = _stats()
	DebugLogger.log(_player, "Serve synthesis | Risk: %.2f | Stamina: %.2f | Style: %s (agg=%.2f risk_tol=%.2f pace_pref=%.2f) | serve_power=%.2f serve_acc=%.2f composure=%.2f" % [
		risk,
		context.player_stamina_ratio,
		play_style.style_name,
		play_style.aggression,
		play_style.risk_tolerance,
		play_style.preferred_rally_pace,
		stats.serve_power01(),
		stats.serve_accuracy01(context.player_stamina_ratio),
		stats.pressure_resistance01()
	])
	
	return _execution.build_stroke(context, _targeting)


func choose_tactical_intent(context: AiPointContext) -> AiPointContext.ShotIntent:
	if context.is_serve:
		return AiPointContext.ShotIntent.SERVE

	var stats = _stats()
	var aggression: float = (play_style.aggression * 0.45) + (stats.tactical_aggression01() * 0.55)
	var net_bias: float = (play_style.net_frequency * 0.45) + (stats.tactical_net_play01() * 0.55)
	var defense: float = stats.tactical_defense01()
	var anticipation: float = stats.anticipation01()
	var pressure_resistance: float = stats.pressure_resistance01()
	var fatigue: float = 1.0 - context.player_stamina_ratio

	if context.short_ball_opportunity and aggression >= 0.48 and randf() < (0.42 + aggression * 0.28):
		return AiPointContext.ShotIntent.ATTACK

	if (context.player_movement_speed > lerpf(5.1, 3.8, anticipation) and context.incoming_ball_speed > 17.0) or (fatigue > 0.45 and pressure_resistance < 0.7):
		if randf() < (0.45 + defense * 0.35):
			return AiPointContext.ShotIntent.DEFEND

	if net_bias > 0.54 and context.ball_height > 0.45 and context.ball_height < 1.45:
		if randf() < clampf(net_bias + aggression * 0.15 - fatigue * 0.2, 0.0, 1.0):
			return AiPointContext.ShotIntent.APPROACH_NET

	if context.opponent_center_distance > lerpf(2.7, 2.2, anticipation) and aggression > 0.52:
		return AiPointContext.ShotIntent.ATTACK

	return AiPointContext.ShotIntent.NEUTRAL


func _compute_shot_risk(context: AiPointContext, intent: AiPointContext.ShotIntent) -> float:
	var stats = _stats()
	var tactical_aggression: float = stats.tactical_aggression01()
	var pressure_resistance: float = stats.pressure_resistance01()
	var base_risk: float = (play_style.risk_tolerance * 0.45) + (tactical_aggression * 0.55)

	if intent == AiPointContext.ShotIntent.ATTACK:
		base_risk += 0.2 * tactical_aggression
	if intent == AiPointContext.ShotIntent.DEFEND:
		base_risk -= 0.18
	if intent == AiPointContext.ShotIntent.APPROACH_NET:
		base_risk += 0.08 * stats.tactical_net_play01()

	if context.short_ball_opportunity:
		base_risk += 0.1

	var incoming_pressure: float = clampf(inverse_lerp(8.0, 32.0, context.incoming_ball_speed), 0.0, 1.0)
	var movement_pressure: float = clampf(inverse_lerp(1.0, 7.0, context.player_movement_speed), 0.0, 1.0)
	var fatigue_pressure: float = 1.0 - context.player_stamina_ratio
	var pressure: float = maxf(maxf(incoming_pressure, movement_pressure), fatigue_pressure)

	# Under pressure, composed players keep attacking options available while fragile profiles trend safer.
	var pressure_safety: float = lerpf(0.6, 0.9, pressure_resistance)
	var pressured_risk: float = base_risk * pressure_safety
	var risk: float = lerpf(base_risk, pressured_risk, pressure)
	return clampf(risk, 0.05, 0.95)
