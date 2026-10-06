class_name PlayerStateMachine
extends Node

signal state_changed(previous_state: State, current_state: State)

enum State {
	IDLE,
	MOVING,
	## A stroke is queued and waits for the ball to arrive.
	PREPARING_STROKE,
	## A stroke animation is playing (swing and follow-through).
	STROKING,
}

const ALLOWED_TRANSITIONS := {
	State.IDLE: [State.MOVING, State.PREPARING_STROKE, State.STROKING],
	State.MOVING: [State.IDLE, State.PREPARING_STROKE, State.STROKING],
	State.PREPARING_STROKE: [State.STROKING, State.IDLE],
	State.STROKING: [State.IDLE, State.PREPARING_STROKE],
}

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
	return true


func can_transition(from_state: State, to_state: State) -> bool:
	return to_state in ALLOWED_TRANSITIONS.get(from_state, [])


## Movement only drives IDLE/MOVING while no stroke is queued or playing.
func is_stroke_in_progress() -> bool:
	return _current_state == State.PREPARING_STROKE or _current_state == State.STROKING
