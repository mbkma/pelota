extends Node

signal level_changed(level_name, init_data)

@export var level_name: String = "level"

#onready var MainMenu = $MainMenu
@onready var start_menu = $StartMenu
@onready var play = start_menu.get_node("Actions/Play")
@onready var SettingsMenu = $SettingsMenu

@onready var player_selectors = [
	start_menu.get_node("HBoxContainer/PlayerSelector"),
	start_menu.get_node("HBoxContainer/PlayerSelector2"),
]

var world = preload("res://src/tennis_location/us_open/us_open.tscn")
var match_data


func init_scene(init_data):
	pass


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	player_selectors[0].input_select_button.text = "CPU"
	player_selectors[1].input_select_button.text = "CPU"

	play.disabled = true

	for p in player_selectors:
		p.selection_changed.connect(on_selection_changed)


#	MusicPlayer.play_playlist(GlobalUtils.get_filepaths_in_directory("res://assets/music/", ".ogg"))


func on_selection_changed() -> void:
	var player_selected = true
	for p in player_selectors:
		if not p.player_selected:
			player_selected = false

	play.disabled = not player_selected


func _on_Start_pressed() -> void:
	start_menu.visible = not start_menu.visible


func _on_Quit_pressed() -> void:
	get_tree().quit()


func _on_Settings_pressed() -> void:
	hide_all_menus()
	SettingsMenu.show()


func _on_Back_pressed() -> void:
	hide_all_menus()


func _on_Play_pressed() -> void:
	GlobalMusicPlayer.stop()

	var players_data := []
	for ps in player_selectors:
		var player_selector = ps as PlayerSelector
		var player_data: PlayerData
		player_data = GlobalGameData.get_player_data_by_index(player_selector.player_index)
		players_data.append(player_data)

	match_data = MatchData.new(players_data[0], players_data[1])

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	print({"match_data": match_data, "world": world})
	emit_signal(
		"level_changed",
		load("res://src/tennis_session/match/singles_match.tscn"),
		{"match_data": match_data, "world": world}
	)


func _on_Tournament_pressed() -> void:
	emit_signal("level_changed", load("res://src/menus/tournament-main-menu.tscn"), null)


func hide_all_menus() -> void:
	start_menu.hide()
	SettingsMenu.hide()


func _on_Career_pressed() -> void:
	emit_signal("level_changed", load("res://src/career/new_career.tscn"), null)


func _on_training_pressed() -> void:
	emit_signal(
		"level_changed",
		load("res://src/tennis_location/training_center/training_center.tscn"),
		null
	)
