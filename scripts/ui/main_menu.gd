extends Node

signal level_changed(level_name, init_data)

@export var level_name: String = "level"
@export var match_scence: PackedScene
@export var training_scence: PackedScene
@export var career_scence: PackedScene
@export var tournament_scence: PackedScene


@onready var main_menu: VBoxContainer = $CenterContainer/VBoxContainer/MenuContainer
@onready var start_menu = $StartMenu
@onready var play = start_menu.get_node("Actions/Play")
@onready var settings_menu: SettingsMenu = $SettingsMenu

@onready var player_selectors = [
	start_menu.get_node("HBoxContainer/PlayerSelector"),
	start_menu.get_node("HBoxContainer/PlayerSelector2"),
]

@onready var back_button = start_menu.get_node("Actions/Back")
@onready var first_main_menu_button = main_menu.get_child(0)

var match_data


func init_scene():
	pass


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	player_selectors[0].input_select_button.text = "CPU"
	player_selectors[1].input_select_button.text = "CPU"

	play.disabled = true

	for p in player_selectors:
		p.selection_changed.connect(on_selection_changed)

	GlobalScenes.music_player.play_track_list(GlobalScenes.music_player.music, true, true)

	# Animate button entrance and set initial focus
	_animate_buttons_entrance()
	_show_main_menu()


func on_selection_changed() -> void:
	var player_selected = true
	for p in player_selectors:
		if not p.player_selected:
			player_selected = false

	play.disabled = not player_selected


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	main_menu.hide()
	settings_menu.show()
	_focus_settings_menu()


func _on_Back_pressed() -> void:
	start_menu.hide()
	_show_main_menu()


func _on_Play_pressed() -> void:
	GlobalScenes.music_player.stop_music()

	var players_data := []
	for ps in player_selectors:
		var player_selector = ps as PlayerSelector
		var player_data: PlayerData
		player_data = GlobalGameData.get_player_data_by_index(player_selector.player_index)
		players_data.append(player_data)

	match_data = MatchData.new(players_data[0], players_data[1])

	level_changed.emit(
		match_scence, null
	)

	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	#print({"match_data": match_data, "world": world})
	#emit_signal(
	#"level_changed",
	#load("res://src/modes/tennis_session/match/singles_match.tscn"),
	#{"match_data": match_data, "world": world}
	#)


func _on_tournament_pressed() -> void:
	level_changed.emit(tournament_scence, null)


func _show_main_menu() -> void:
	main_menu.show()
	first_main_menu_button.call_deferred("grab_focus")


func _show_start_menu() -> void:
	start_menu.show()
	player_selectors[0].call_deferred("grab_focus")


func _on_career_pressed() -> void:
	level_changed.emit(career_scence, null)


func _on_training_pressed() -> void:
	level_changed.emit(
		training_scence, null
	)


func _on_settings_menu_settings_menu_closed() -> void:
	settings_menu.hide()
	_show_main_menu()


func _on_start_pressed() -> void:
	_show_start_menu()


func _animate_buttons_entrance() -> void:
	var buttons = main_menu.get_children()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	for i in range(buttons.size()):
		var button = buttons[i]
		button.modulate.a = 0.0
		button.scale = Vector2(0.8, 0.8)

		tween.tween_property(button, "modulate:a", 1.0, 0.6).set_delay(i * 0.1)
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.6).set_delay(i * 0.1)

	await tween.finished


func _focus_settings_menu() -> void:
	# Find the first focusable element in the settings menu
	settings_menu.call_deferred("grab_focus")
	var first_focusable = _find_first_focusable(settings_menu)
	if first_focusable:
		first_focusable.call_deferred("grab_focus")


func _find_first_focusable(node: Node) -> Control:
	if node is Control:
		if node.focus_mode == Control.FOCUS_ALL:
			return node as Control

	for child in node.get_children():
		var result = _find_first_focusable(child)
		if result:
			return result

	return null
