class_name PlayerStateMachine
extends Node

enum State {
	IDLE,
	MOVING,
	PREPARING_STROKE,
	STROKING,
	RECOVERING,
	UNREACHABLE,
}

signal state_changed(previous_state: State, current_state: State)
signal state_entered(state: State)

var _current_state: State = State.IDLE


func get_state() -> State:
	return _current_state


func transition_to(next_state: State) -> bool:
	if _current_state == next_state:
		return false

	if not can_transition(_current_state, next_state):
		push_warning("Invalid player state transition: ", _current_state, " -> ", next_state)
		return false

	var previous_state: State = _current_state
	_current_state = next_state
	state_changed.emit(previous_state, _current_state)
	state_entered.emit(_current_state)
	return true


func can_transition(from_state: State, to_state: State) -> bool:
	match from_state:
		State.IDLE:
			return to_state in [State.MOVING, State.PREPARING_STROKE, State.STROKING, State.UNREACHABLE]
		State.MOVING:
			return to_state in [State.IDLE, State.PREPARING_STROKE, State.STROKING, State.UNREACHABLE]
		State.PREPARING_STROKE:
			return to_state in [State.STROKING, State.MOVING, State.IDLE, State.UNREACHABLE]
		State.STROKING:
			return to_state in [State.RECOVERING, State.IDLE, State.UNREACHABLE]
		State.RECOVERING:
			return to_state in [State.IDLE, State.MOVING, State.UNREACHABLE]
		State.UNREACHABLE:
			return to_state in [State.IDLE, State.MOVING, State.PREPARING_STROKE]
		_:
			return false


func blocks_movement_animation() -> bool:
	return _current_state == State.STROKING or _current_state == State.RECOVERING
