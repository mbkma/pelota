class_name TennisMatch
extends Node

@export var ai_controller_scene: PackedScene
@export var human_controller_scene: PackedScene


func _enter_tree() -> void:
	# The menu music stops when the match begins (no music director when the match is run
	# directly).
	var music_director: MusicDirector = get_tree().root.get_node_or_null(^"MusicDirector")
	if music_director:
		music_director.stop()

	if not GlobalGameData.has_match_players():
		return

	var players: Array[PlayerData] = GlobalGameData.get_match_players()
	if players.size() < 2:
		return

	var player0 := get_node_or_null("Player") as Player
	var player1 := get_node_or_null("Player2") as Player
	if player0:
		player0.team_index = 0
		player0.controller_scene = _controller_scene_for_team(0)
		player0.player_data = players[0]
	if player1:
		player1.team_index = 1
		player1.controller_scene = _controller_scene_for_team(1)
		player1.player_data = players[1]


func _controller_scene_for_team(team_index: int) -> PackedScene:
	if GlobalGameData.is_human_controlled(team_index):
		return human_controller_scene
	return ai_controller_scene
