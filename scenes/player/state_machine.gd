class_name PlayerStateMachine
extends Node

enum State {
	IDLE,
	MOVING,
	## A stroke is queued and waits for the ball to arrive.
	PREPARING_STROKE,
	## A stroke animation is playing (swing and follow-through).
	STROKING,
}

const ALLOWED_TRANSITIONS: Dictionary[State, Array] = {
	State.IDLE: [State.MOVING, State.PREPARING_STROKE, State.STROKING],
	State.MOVING: [State.IDLE, State.PREPARING_STROKE, State.STROKING],
	State.PREPARING_STROKE: [State.STROKING, State.IDLE],
	State.STROKING: [State.IDLE, State.PREPARING_STROKE],
}

var _current_state: State = State.IDLE


func get_state() -> State:
	return _current_state


func transition_to(next_state: State) -> void:
	if _current_state == next_state:
		return
	if next_state not in ALLOWED_TRANSITIONS[_current_state]:
		push_warning("Invalid player state transition: ", _current_state, " -> ", next_state)
		return
	_current_state = next_state


## Movement only drives IDLE/MOVING while no stroke is queued or playing.
func is_stroke_in_progress() -> bool:
	return _current_state == State.PREPARING_STROKE or _current_state == State.STROKING
