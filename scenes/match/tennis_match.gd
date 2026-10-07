## Root of a match: puts the players picked in the menu on court. Run directly, the match
## uses the players set in the scene.
class_name TennisMatch
extends Node

@export var player0: Player
@export var player1: Player


func _enter_tree() -> void:
	# The menu music stops when the match begins (no music director when the match is run
	# directly).
	var music_director: MusicDirector = get_tree().root.get_node_or_null(^"MusicDirector")
	if music_director:
		music_director.stop()

	if GlobalGameData.has_match_players():
		player0.player_data = GlobalGameData.selected_match_player
		player1.player_data = GlobalGameData.selected_match_opponent
