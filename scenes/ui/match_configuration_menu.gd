extends Control

@export var match_scence: PackedScene
@onready var player_selectors = [
	$CenterContainer/VBoxContainer/HBoxContainer/PlayerSelector,
	$CenterContainer/VBoxContainer/HBoxContainer/PlayerSelector2,
]

@onready var play = $CenterContainer/VBoxContainer/PlayButton

var match_data


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player_selectors[0].input_select_button.text = "CPU"
	player_selectors[1].input_select_button.text = "CPU"
	play.disabled = true

	for p in player_selectors:
		p.selection_changed.connect(on_selection_changed)


func on_selection_changed() -> void:
	var player_selected = true
	for p in player_selectors:
		if not p.player_selected:
			player_selected = false

	play.disabled = not player_selected


func _on_play_button_pressed() -> void:
	var players_data := []
	for ps in player_selectors:
		var player_selector = ps as PlayerSelector
		var player_data: PlayerData
		player_data = GlobalGameData.get_player_data_by_index(player_selector.player_index)
		players_data.append(player_data)

	match_data = MatchData.new(players_data[0], players_data[1])

	
	SceneManager.goto(match_scence)
