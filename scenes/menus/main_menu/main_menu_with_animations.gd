extends MainMenu
## Main menu extension: animates the title and menu fading in (the player can skip it with
## any input), starts the music, opens the how-to-play screen and the player select before
## a new match, a training or a tournament, and continues a saved tournament.

## Player select opened by 'New Game'; confirming it starts the match.
@export var player_select_packed_scene: PackedScene
## Plays the music (a random song per game launch) and keeps running across scenes.
@export var music_director_scene: PackedScene
## How-to-play screen opened by the 'How to Play' button.
@export var tutorial_packed_scene: PackedScene
## Player select opened by 'Training'; confirming it starts the training.
@export var training_select_packed_scene: PackedScene
@export_file("*.tscn") var training_scene_path: String
## Player select opened by 'US Open'; confirming it starts a new tournament.
@export var tournament_select_packed_scene: PackedScene
## The tournament's draw, opened when a tournament starts or continues
@export_file("*.tscn") var tournament_scene_path: String

var animation_state_machine: AnimationNodeStateMachinePlayback
## The saved tournament, null if there is none
var _saved_tournament: Tournament


func _ready() -> void:
	super._ready()
	_start_music_once()
	animation_state_machine = $MenuAnimationTree.get("parameters/playback")
	_saved_tournament = Tournament.load_saved()
	%ContinueTournamentButton.visible = _saved_tournament != null
	%ContinueTournamentButton.text = "Continue %s" % Tournament.NAME
	%TournamentButton.text = Tournament.NAME


func _input(event: InputEvent) -> void:
	if _is_in_intro() and _event_skips_intro(event):
		intro_done()
		return
	super._input(event)


func new_game() -> void:
	_open_sub_menu(player_select_packed_scene).selection_confirmed.connect(load_game_scene)


func intro_done() -> void:
	animation_state_machine.travel("OpenMainMenu")


func _is_in_intro() -> bool:
	return animation_state_machine.get_current_node() == "Intro"


func _event_skips_intro(event: InputEvent) -> bool:
	return (
		event.is_action_released("ui_accept")
		or event.is_action_released("ui_select")
		or event.is_action_released("ui_cancel")
	)


func _open_sub_menu(menu: PackedScene) -> Node:
	animation_state_machine.travel("OpenSubMenu")
	return super._open_sub_menu(menu)


func _close_sub_menu() -> void:
	super._close_sub_menu()
	animation_state_machine.travel("OpenMainMenu")


## Starts the music director the first time the main menu opens; afterwards (e.g. back from a
## match) resumes the music.
func _start_music_once() -> void:
	var director: MusicDirector = get_tree().root.get_node_or_null(^"MusicDirector")
	if director:
		director.resume()
		return
	get_tree().root.add_child.call_deferred(music_director_scene.instantiate())


func _on_how_to_play_button_pressed() -> void:
	_open_sub_menu(tutorial_packed_scene)


func _on_tournament_button_pressed() -> void:
	_open_sub_menu(tournament_select_packed_scene).selection_confirmed.connect(
		SceneLoader.load_scene.bind(tournament_scene_path)
	)


## Continues the saved tournament, played with the first connected device.
func _on_continue_tournament_button_pressed() -> void:
	GlobalGameData.continue_tournament(_saved_tournament, InputDevice.get_connected_device_ids()[0])
	SceneLoader.load_scene(tournament_scene_path)


func _on_training_button_pressed() -> void:
	_open_sub_menu(training_select_packed_scene).selection_confirmed.connect(
		SceneLoader.load_scene.bind(training_scene_path)
	)
