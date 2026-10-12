## Root of a match: puts the players picked in the menu on court. Run directly, the match
## uses the players of the player scene. A match of a tournament is recorded in it once played.
class_name TennisMatch
extends Node

## Where each player starts, by team (z, m): at the baselines, the match manager places them
## for the first serve once it is ready
const START_Z: float = 12.0

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

@export var match_manager: MatchManager
@export var splitscreen: SplitscreenManager
## The status panel of each player, by team
@export var status_panels: Array[PlayerStatusPanel] = []

var player0: Player
var player1: Player


## The players are made with the match, before the nodes of the scene: as its first children they
## are ready before the nodes using them (a child added later is ready after all the others).
func _init() -> void:
	player0 = _add_player(0)
	player1 = _add_player(1)


func _enter_tree() -> void:
	# The menu music stops when the match begins (no music director when the match is run
	# directly).
	var music_director: MusicDirector = get_tree().root.get_node_or_null(^"MusicDirector")
	if music_director:
		music_director.stop()

	match_manager.player0 = player0
	match_manager.player1 = player1
	splitscreen.player0 = player0
	splitscreen.player1 = player1
	status_panels[0].player = player0
	status_panels[1].player = player1


func _ready() -> void:
	if GlobalGameData.tournament:
		match_manager.match_finished.connect(_record_tournament_match.unbind(1))


## Adds the player of team `team_index`, with the player picked in the menu if there is one.
func _add_player(team_index: int) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = "Player" if team_index == 0 else "Player2"
	player.team_index = team_index
	if GlobalGameData.has_match_players():
		player.player_data = (
			GlobalGameData.selected_match_opponent
			if team_index == 1
			else GlobalGameData.selected_match_player
		)
	player.position = Vector3(0.0, 0.0, START_Z if team_index == 0 else -START_Z)
	add_child(player)
	return player


## Records the finished match in the tournament (the player is player 0) and saves it.
func _record_tournament_match() -> void:
	GlobalGameData.tournament.record_player_match(match_manager.match_data.score)
	GlobalGameData.tournament.save()
