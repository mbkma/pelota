extends Control

var sm
@onready var list: List = $List

var fps_entry
var valid_side_entry
var ball_in_play_entry
var state_entry


func _ready() -> void:
	list.add_entry("Godot version:", Engine.get_version_info()["string"])
	list.add_entry("OS:", OS.get_name())
	fps_entry = list.add_entry("FPS:", "")


func _process(delta: float) -> void:
	if sm:
		valid_side_entry.right.text = str(sm.valid_side)
		ball_in_play_entry.right.text = str(sm.ball_in_play)

	fps_entry.update(Engine.get_frames_per_second())


func setup_singles_match(singles_match: SinglesMatch):
	sm = singles_match
	sm.connect("state_changed", Callable(self, "on_SinglesMatch_state_changed"))
	state_entry = list.add_entry("State:", str(sm.state))
	if sm:
		valid_side_entry = list.add_entry("Valid Side:", "")
		ball_in_play_entry = list.add_entry("Ball In Play:", "")


func on_SinglesMatch_state_changed(old_state, new_state):
	state_entry.text = str(new_state)
	if new_state == GlobalUtils.MatchStates.FAULT or new_state == GlobalUtils.MatchStates.IDLE:
		state_entry.text += ", fault reason: " + sm.fault_reason
