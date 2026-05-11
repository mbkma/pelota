class_name PointStrategy
extends Resource

@export var play_style: AiPlayStyle

var _player: Player
var _selector := ShotSelector.new()
var _execution := ShotExecution.new()
var _targeting := NormalizedCourtTargeting.new()


func setup(target_player: Player) -> void:
	_player = target_player


func compute_next_stroke(closest_step: TrajectoryStep) -> Stroke:
	if not _player:
		push_error("PointStrategy.compute_next_stroke: setup(player) must be called before use")
		return null
	if not play_style:
		push_error("PointStrategy.compute_next_stroke: play_style is not configured")
		return null

	var context := AiPointContext.from_step(_player, closest_step, false)
	var intent := choose_tactical_intent(context)
	var pattern := _selector.select_pattern(context, play_style, intent, false)
	if not pattern:
		push_error("PointStrategy.compute_next_stroke: no shot pattern matched context")
		return null
	return _execution.build_stroke(pattern, context, _targeting)


func compute_serve() -> Stroke:
	if not _player:
		push_error("PointStrategy.compute_serve: setup(player) must be called before use")
		return null
	if not play_style:
		push_error("PointStrategy.compute_serve: play_style is not configured")
		return null

	var context := AiPointContext.from_step(_player, null, true)
	var intent := ShotPattern.TacticalIntent.SERVE
	var pattern := _selector.select_pattern(context, play_style, intent, true)
	if not pattern:
		push_error("PointStrategy.compute_serve: no serve pattern matched context")
		return null
	return _execution.build_stroke(pattern, context, _targeting)


func choose_tactical_intent(context: AiPointContext) -> ShotPattern.TacticalIntent:
	if context.is_serve:
		return ShotPattern.TacticalIntent.SERVE

	if context.short_ball_opportunity and play_style.aggression >= 0.45:
		return ShotPattern.TacticalIntent.ATTACK

	if context.player_movement_speed > 4.5 and context.incoming_ball_speed > 17.0:
		return ShotPattern.TacticalIntent.DEFEND

	if play_style.net_frequency > 0.7 and context.ball_height > 0.5 and context.ball_height < 1.4:
		if randf() < play_style.net_frequency:
			return ShotPattern.TacticalIntent.APPROACH_NET

	if context.opponent_center_distance > 2.4 and play_style.risk_tolerance > 0.55:
		return ShotPattern.TacticalIntent.ATTACK

	return ShotPattern.TacticalIntent.NEUTRAL
