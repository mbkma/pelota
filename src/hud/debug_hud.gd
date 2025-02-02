extends Control

const entry = preload("res://src/hud/entry.tscn")
@onready var list: VBoxContainer = $List
var sm

var fps_entry
var valid_side_entry
var ball_in_play_entry
var state_entry


func _ready() -> void:
	add_entry("Godot version:", Engine.get_version_info()["string"])
	add_entry("OS:", OS.get_name())
	fps_entry = add_entry("FPS:", "")




func _init() -> void:
	if Input.is_action_just_pressed("toggle"):
		visible = not visible


func _process(delta: float) -> void:
	if sm:
		valid_side_entry.text = str(sm.valid_side)
		ball_in_play_entry.text = str(sm.ball_in_play)

	fps_entry.text = str(Engine.get_frames_per_second())


func setup_singles_match(singles_match: SinglesMatch):
	sm = singles_match
	sm.connect("state_changed", Callable(self, "on_SinglesMatch_state_changed"))
	state_entry = add_entry("State:", str(sm.state))
	if sm:
		valid_side_entry = add_entry("Valid Side:", "")
		ball_in_play_entry = add_entry("Ball In Play:", "")

func on_SinglesMatch_state_changed(old_state, new_state):
	state_entry.text = str(new_state)
	if new_state == GlobalUtils.MatchStates.FAULT or new_state == GlobalUtils.MatchStates.IDLE:
		state_entry.text += ", fault reason: " + sm.fault_reason


func add_entry(left_text, right_text):
	var e = entry.instantiate()
	e.label = left_text
	e.text = right_text
	list.add_child(e)
	return e


func get_entry(index):
	return list.get_child(index)
