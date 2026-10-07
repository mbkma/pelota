extends Node

const CHARACTER_DATA_DIR := "res://scenes/player/resources/data/"

var selected_match_player: PlayerData
var selected_match_opponent: PlayerData
## Input device id per team; InputDevice.NO_DEVICE_ID means the team is AI controlled.
var _match_input_devices: Array[int] = [InputDevice.NO_DEVICE_ID, InputDevice.NO_DEVICE_ID]
var _players: Array[PlayerData] = []

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	load_players()


class MyCustomSorter:
	static func sort_ascending_by_rank(a, b):
		if a.rank < b.rank:
			return true
		return false


func load_players() -> void:
	_players.clear()

	var directory := DirAccess.open(CHARACTER_DATA_DIR)
	if directory == null:
		push_warning("GlobalGameData: Unable to open player directory at %s" % CHARACTER_DATA_DIR)
		return

	var resource_paths: Array[String] = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "tres":
			resource_paths.append("%s/%s" % [CHARACTER_DATA_DIR, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()

	resource_paths.sort()
	for resource_path in resource_paths:
		var loaded_resource := load(resource_path)
		if loaded_resource is PlayerData:
			_players.append(loaded_resource as PlayerData)

	_players.sort_custom(Callable(MyCustomSorter, "sort_ascending_by_rank"))


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


func get_match_players() -> Array[PlayerData]:
	if not has_match_players():
		return []
	return [selected_match_player, selected_match_opponent]
