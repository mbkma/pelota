## Phases of a player's part in a point (serve setup, serve, rally, point end) and the events
## between them.
class_name MatchLifecycleBus
extends Node

signal phase_changed(current_phase: Phase)
signal serve_requested(player: Player)
signal serve_completed(player: Player)
signal point_ended(player: Player)

enum Phase {
	IDLE,
	SERVE_SETUP,
	SERVING,
	RALLY,
	POINT_ENDED,
}

var _current_phase: Phase = Phase.IDLE


func set_phase(next_phase: Phase) -> void:
	if _current_phase == next_phase:
		return
	_current_phase = next_phase
	phase_changed.emit(_current_phase)


func begin_serve_setup(player: Player) -> void:
	set_phase(Phase.SERVE_SETUP)
	serve_requested.emit(player)


func start_serving() -> void:
	set_phase(Phase.SERVING)


func complete_serve(player: Player) -> void:
	serve_completed.emit(player)
	set_phase(Phase.RALLY)


func end_point(player: Player) -> void:
	set_phase(Phase.POINT_ENDED)
	point_ended.emit(player)
