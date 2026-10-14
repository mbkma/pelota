## Global game data: the available players, the selection for the next match or training, and
## the tournament being played.
extends Node

## The devices controlling the teams changed (see set_match_input_devices)
signal match_input_devices_changed

const CHARACTER_DATA_DIR := "res://scenes/player/resources/data/"
## Sets of a match outside a tournament
const DEFAULT_BEST_OF_SETS: int = 3

## Players of the next match; null until picked in the player select menu
var selected_match_player: PlayerData
var selected_match_opponent: PlayerData
## Player of the next training; null until picked in the training select menu
var selected_training_player: PlayerData
## Sets of the next match
var best_of_sets: int = DEFAULT_BEST_OF_SETS
## The tournament being played; null outside a tournament
var tournament: Tournament
## Input device id per team; InputDevice.NO_DEVICE_ID means the team is AI controlled.
var _match_input_devices: Array[int] = [InputDevice.NO_DEVICE_ID, InputDevice.NO_DEVICE_ID]
## All players, best ranked first, unranked players last
var _players: Array[PlayerData] = []


func _ready() -> void:
	for file_name in ResourceLoader.list_directory(CHARACTER_DATA_DIR):
		if file_name.get_extension() == "tres":
			_players.append(load(CHARACTER_DATA_DIR.path_join(file_name)))
	_players.sort_custom(_ranked_before)


func get_players() -> Array[PlayerData]:
	return _players.duplicate()


## The players with an ATP ranking, best ranked first
func get_ranked_players() -> Array[PlayerData]:
	return _players.filter(func(p: PlayerData) -> bool: return p.rank > 0)


static func _ranked_before(a: PlayerData, b: PlayerData) -> bool:
	if (a.rank > 0) != (b.rank > 0):
		return a.rank > 0
	return a.rank < b.rank


## Sets up a match outside a tournament.
func set_match_players(player: PlayerData, opponent: PlayerData) -> void:
	tournament = null
	best_of_sets = DEFAULT_BEST_OF_SETS
	selected_match_player = player
	selected_match_opponent = opponent


## Starts a new tournament of the ranked players, in which the player plays `player`; it
## replaces a saved one.
func start_tournament(player: PlayerData) -> void:
	tournament = Tournament.create(get_ranked_players(), player, DEFAULT_BEST_OF_SETS)
	tournament.save()


## Continues the saved `saved_tournament`, the player playing with `device_id`.
func continue_tournament(saved_tournament: Tournament, device_id: int) -> void:
	tournament = saved_tournament
	set_match_input_devices(device_id, InputDevice.NO_DEVICE_ID)


## Sets up the player's next match of the tournament: the player against the opponent in the
## draw, over the tournament's sets.
func prepare_tournament_match() -> void:
	var own_match: TournamentMatch = tournament.player_match()
	var opponent: PlayerData = own_match.players[1 - own_match.players.find(tournament.player)]
	selected_match_player = tournament.player
	selected_match_opponent = opponent
	best_of_sets = tournament.best_of_sets


func set_training_player(player: PlayerData) -> void:
	selected_training_player = player


func set_match_input_devices(player1_device_id: int, player2_device_id: int) -> void:
	_match_input_devices = [player1_device_id, player2_device_id]
	match_input_devices_changed.emit()


func get_match_input_device(team_index: int) -> int:
	return _match_input_devices[team_index]


func is_human_controlled(team_index: int) -> bool:
	return _match_input_devices[team_index] != InputDevice.NO_DEVICE_ID


func has_match_players() -> bool:
	return selected_match_player != null and selected_match_opponent != null
