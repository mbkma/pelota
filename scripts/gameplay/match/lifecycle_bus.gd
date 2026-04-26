class_name MatchLifecycleBus
extends Node

enum Phase {
	IDLE,
	SERVE_SETUP,
	SERVING,
	RALLY,
	POINT_ENDED,
}

signal phase_changed(previous_phase: Phase, current_phase: Phase)
signal serve_requested(player)
signal serve_started(player, stroke)
signal serve_completed(player)
signal rally_started(player)
signal rally_ended(player)
signal point_ended(player)

var _current_phase: Phase = Phase.IDLE


func get_phase() -> Phase:
	return _current_phase


func set_phase(next_phase: Phase) -> void:
	if _current_phase == next_phase:
		return

	var previous_phase: Phase = _current_phase
	_current_phase = next_phase
	phase_changed.emit(previous_phase, _current_phase)


func begin_serve_setup(player) -> void:
	set_phase(Phase.SERVE_SETUP)
	serve_requested.emit(player)


func start_serving(player, stroke: Stroke) -> void:
	set_phase(Phase.SERVING)
	serve_started.emit(player, stroke)


func complete_serve(player) -> void:
	serve_completed.emit(player)
	set_phase(Phase.RALLY)
	rally_started.emit(player)


func end_point(player) -> void:
	rally_ended.emit(player)
	set_phase(Phase.POINT_ENDED)
	point_ended.emit(player)
