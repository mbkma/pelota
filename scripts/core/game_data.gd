## Global game data: the available players, the selection for the next match or training (or the
## saved match it continues), and the tournament being played.
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
## The saved match the next match continues; null for a new match
var resumed_match: SavedMatch
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
	resumed_match = null
	best_of_sets = DEFAULT_BEST_OF_SETS
	selected_match_player = player
	selected_match_opponent = opponent


## Starts a new tournament of the ranked players, in which the player plays `player`; it
## replaces a saved one (and a saved match of it).
func start_tournament(player: PlayerData) -> void:
	tournament = Tournament.create(get_ranked_players(), player, DEFAULT_BEST_OF_SETS)
	tournament.save()
	SavedMatch.delete_saved(true)


## Continues `saved`, a match outside a tournament, with the devices it was played with that are
## still connected: player 1 with the first connected device otherwise, player 2 by the CPU.
func continue_match(saved: SavedMatch) -> void:
	tournament = null
	resumed_match = saved
	selected_match_player = saved.players[0]
	selected_match_opponent = saved.players[1]
	best_of_sets = saved.match_data.score.best_of_sets
	var connected: Array[int] = InputDevice.get_connected_device_ids()
	var player1_device: int = saved.input_devices[0]
	if player1_device != InputDevice.NO_DEVICE_ID and player1_device not in connected:
		player1_device = connected[0]
	var player2_device: int = saved.input_devices[1]
	if player2_device not in connected or player2_device == player1_device:
		player2_device = InputDevice.NO_DEVICE_ID
	set_match_input_devices(player1_device, player2_device)


## Continues the saved `saved_tournament`, the player playing with `device_id`.
func continue_tournament(saved_tournament: Tournament, device_id: int) -> void:
	tournament = saved_tournament
	set_match_input_devices(device_id, InputDevice.NO_DEVICE_ID)


## Sets up the player's next match of the tournament: the player against the opponent in the
## draw, over the tournament's sets, or the saved match of it to continue.
func prepare_tournament_match() -> void:
	selected_match_player = tournament.player
	selected_match_opponent = tournament.player_match().opponent_of(tournament.player)
	resumed_match = saved_tournament_match()
	best_of_sets = (
		resumed_match.match_data.score.best_of_sets if resumed_match else tournament.best_of_sets
	)


## The saved match of the player's next match of the tournament, null if there is none.
func saved_tournament_match() -> SavedMatch:
	var saved: SavedMatch = SavedMatch.load_saved(true)
	var own_match: TournamentMatch = tournament.player_match()
	if not saved or not own_match:
		return null
	if not saved.is_between(tournament.player, own_match.opponent_of(tournament.player)):
		return null
	return saved


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
