extends Control

const entry = preload("res://src/hud/entry.tscn")
@onready var list: VBoxContainer = $List
var sm

@export var player: Player

var fps_entry
var valid_side_entry
var ball_in_play_entry
var state_entry


func _ready() -> void:
	add_entry("Id", player.player_data.to_string())

	add_entry("active stroke", player.active_stroke)
	add_entry("model playback node", player.model._playback.get_current_node())


func _process(delta: float) -> void:
	get_entry(2).text = str(player.model._playback.get_current_node())


func add_entry(left_text, right_text):
	var e = entry.instantiate()
	e.label = str(left_text)
	e.text = str(right_text) if right_text else "Null"
	list.add_child(e)
	return e


func get_entry(index):
	return list.get_child(index)
