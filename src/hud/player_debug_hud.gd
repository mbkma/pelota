extends Control

var sm
@onready var list: List = $List

@export var player: Player

var fps_entry
var valid_side_entry
var ball_in_play_entry
var state_entry


func _ready() -> void:
	if not player:
		return

	list.add_entry("Id", player.player_data.last_name)

	list.add_entry("active stroke", player.active_stroke)
	list.add_entry("model playback node", player.model._playback.get_current_node())

	if player.input != player.InputType.AI:
		list.add_entry("input blocked", player.input_node.input_blocked)
		list.add_entry("stroke input blocked", player.input_node.stroke_input_blocked)
		list.add_entry("move input blocked", player.input_node.move_input_blocked)


func _process(delta: float) -> void:
	if not player:
		return
	list.get_entry(2).update(player.model._playback.get_current_node())

	if player.input != player.InputType.AI:
		list.get_entry(3).update(player.input_node.stroke_input_blocked)
		list.get_entry(4).update(player.input_node.input_blocked)
		list.get_entry(5).update(player.input_node.move_input_blocked)
