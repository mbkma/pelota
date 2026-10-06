class_name PointStrategy
extends Resource

## Play style resource that configures dynamic shot behavior.
@export var play_style: AiPlayStyle

var _player: Player
var _planner := ShotPlanner.new()
var _executor := ShotExecutor.new()
var _targeting := NormalizedCourtTargeting.new()


func _stats() -> PlayerRuntimeStats:
	assert(_player != null, "PointStrategy._stats: setup(player) must be called before use")
	assert(_player.stats != null, "PointStrategy._stats: player.stats is required")
	return _player.stats


func setup(target_player: Player) -> void:
	_player = target_player
	if not play_style and _player and _player.player_data and _player.player_data.play_style:
		play_style = _player.player_data.play_style


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
	var plan: Dictionary = _planner.build_shot_plan(context, play_style)
	if plan.is_empty():
		push_error("PointStrategy.compute_next_stroke: no plan could be selected")
		return null
	context.selected_intent = plan.intent
	context.selected_target_lane = plan.target_lane
	context.shot_risk = plan.risk
	context.play_style = play_style

	var stats = _stats()
	DebugLogger.log(
		_player,
		(
			(
				"AI | Choice: %s | Stamina: %.2f | Ball: %.2f m/s@%.2fm "
				+ "| Player speed: %.2f | Opp dist: %.2f | agg=%.2f def=%.2f ant=%.2f"
			)
			% [
				plan.debug,
				context.player_stamina_ratio,
				context.incoming_ball_speed,
				context.ball_height,
				context.player_movement_speed,
				context.opponent_center_distance,
				stats.tactical_aggression01(),
				stats.tactical_defense01(),
				stats.anticipation01()
			]
		)
	)

	return _executor.build_stroke(context, _targeting)


func compute_serve() -> Stroke:
	if not _player:
		push_error("PointStrategy.compute_serve: setup(player) must be called before use")
		return null
	if not play_style:
		push_error("PointStrategy.compute_serve: play_style is not configured")
		return null

	var context := AiPointContext.from_step(_player, null, true)
	var plan: Dictionary = _planner.build_shot_plan(context, play_style)
	if plan.is_empty():
		push_error("PointStrategy.compute_serve: no plan could be selected")
		return null
	context.selected_intent = plan.intent
	context.selected_target_lane = plan.target_lane
	context.shot_risk = plan.risk
	context.play_style = play_style

	var stats = _stats()
	DebugLogger.log(
		_player,
		(
			(
				"Serve synthesis | Selected: %s | Stamina: %.2f "
				+ "| Style (agg=%.2f power=%.2f topspin=%.2f court=%.2f consistency=%.2f) "
				+ "| serve_power=%.2f serve_acc=%.2f composure=%.2f"
			)
			% [
				plan.debug,
				context.player_stamina_ratio,
				play_style.aggression,
				play_style.shot_power,
				play_style.topspin,
				play_style.court_position,
				play_style.consistency,
				stats.serve_power01(),
				stats.serve_accuracy01(context.player_stamina_ratio),
				stats.pressure_resistance01()
			]
		)
	)

	return _executor.build_stroke(context, _targeting)
