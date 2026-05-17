extends Node

enum InputMethod {
	AI,
	HUMAN,
}

var selected_match_player: PlayerData
var selected_match_opponent: PlayerData
var selected_player1_input_method: int = InputMethod.AI
var selected_player2_input_method: int = InputMethod.AI

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	load_players()


class MyCustomSorter:
	static func sort_ascending_by_rank(a, b):
		if a.rank < b.rank:
			return true
		return false


func load_players():
	GlobalScenes.PLAYER_DATA.sort_custom(Callable(MyCustomSorter, "sort_ascending_by_rank"))


func get_player_data_by_index(index: int) -> PlayerData:
	return GlobalScenes.PLAYER_DATA[index]


func set_match_players(player: PlayerData, opponent: PlayerData) -> void:
	selected_match_player = player
	selected_match_opponent = opponent


func set_match_input_methods(player1_input_method: int, player2_input_method: int) -> void:
	selected_player1_input_method = _sanitize_input_method(player1_input_method)
	selected_player2_input_method = _sanitize_input_method(player2_input_method)


func get_match_input_methods() -> Array[int]:
	return [selected_player1_input_method, selected_player2_input_method]


func _sanitize_input_method(input_method: int) -> int:
	if input_method == InputMethod.HUMAN:
		return InputMethod.HUMAN
	return InputMethod.AI


func clear_match_players() -> void:
	selected_match_player = null
	selected_match_opponent = null


func has_match_players() -> bool:
	return selected_match_player != null and selected_match_opponent != null


func get_match_players() -> Array[PlayerData]:
	if not has_match_players():
		return []
	return [selected_match_player, selected_match_opponent]
