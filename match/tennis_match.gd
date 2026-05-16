class_name TennisMatch
extends Node

@export var ai_controller_scene: PackedScene
@export var human_controller_scene: PackedScene


func _enter_tree() -> void:
	if not GlobalGameData.has_match_players():
		return

	var players: Array[PlayerData] = GlobalGameData.get_match_players()
	if players.size() < 2:
		return

	var player0 := get_node_or_null("Player") as Player
	var player1 := get_node_or_null("Player2") as Player
	var input_methods: Array[int] = GlobalGameData.get_match_input_methods()
	if player0:
		player0.controller_scene = _controller_scene_for_input_method(input_methods[0])
		player0.player_data = players[0]
	if player1:
		player1.controller_scene = _controller_scene_for_input_method(input_methods[1])
		player1.player_data = players[1]


func _controller_scene_for_input_method(input_method: int) -> PackedScene:
	if input_method == GlobalGameData.InputMethod.HUMAN:
		return human_controller_scene
	return ai_controller_scene
