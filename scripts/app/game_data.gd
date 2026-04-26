extends Node

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
