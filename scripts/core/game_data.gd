## Global game data: the available players and the selection for the next match.
extends Node

const CHARACTER_DATA_DIR := "res://scenes/player/resources/data/"

## Players of the next match; null until picked in the player select menu
var selected_match_player: PlayerData
var selected_match_opponent: PlayerData
## Input device id per team; InputDevice.NO_DEVICE_ID means the team is AI controlled.
var _match_input_devices: Array[int] = [InputDevice.NO_DEVICE_ID, InputDevice.NO_DEVICE_ID]
## All players, best ranked first
var _players: Array[PlayerData] = []


func _ready() -> void:
	for file_name in ResourceLoader.list_directory(CHARACTER_DATA_DIR):
		if file_name.get_extension() == "tres":
			_players.append(load(CHARACTER_DATA_DIR.path_join(file_name)))
	_players.sort_custom(func(a: PlayerData, b: PlayerData) -> bool: return a.rank < b.rank)


func get_players() -> Array[PlayerData]:
	return _players.duplicate()


func set_match_players(player: PlayerData, opponent: PlayerData) -> void:
	selected_match_player = player
	selected_match_opponent = opponent


func set_match_input_devices(player1_device_id: int, player2_device_id: int) -> void:
	_match_input_devices = [player1_device_id, player2_device_id]


func get_match_input_device(team_index: int) -> int:
	return _match_input_devices[team_index]


func is_human_controlled(team_index: int) -> bool:
	return _match_input_devices[team_index] != InputDevice.NO_DEVICE_ID


func has_match_players() -> bool:
	return selected_match_player != null and selected_match_opponent != null
