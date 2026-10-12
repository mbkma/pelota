extends MainMenu
## Main menu extension: animates the title and menu fading in (the player can skip it with
## any input), starts the music, opens the how-to-play screen, the player select before a new
## match and the modes menu, whose entries (training, tournament, a saved tournament) open
## their own player select or continue.

## Player select opened by 'New Game'; confirming it starts the match.
@export var player_select_packed_scene: PackedScene
## Plays the music (a random song per game launch) and keeps running across scenes.
@export var music_director_scene: PackedScene
## Modes menu opened by the 'Modes' button.
@export var modes_packed_scene: PackedScene
## How-to-play screen opened by the 'How to Play' button.
@export var tutorial_packed_scene: PackedScene
## Player select opened by the modes menu's 'Training'; confirming it starts the training.
@export var training_select_packed_scene: PackedScene
@export_file("*.tscn") var training_scene_path: String
## Player select opened by the modes menu's 'US Open'; confirming it starts a new tournament.
@export var tournament_select_packed_scene: PackedScene
## The tournament's draw, opened when a tournament starts or continues
@export_file("*.tscn") var tournament_scene_path: String

var animation_state_machine: AnimationNodeStateMachinePlayback
## The saved tournament, null if there is none
var _saved_tournament: Tournament
## Whether the modes menu opens again when the sub menu opened from it closes
var _return_to_modes: bool = false
## Releasing ui_cancel closes the open sub menu only after its press reached the main menu: the
## press that closes an open dropdown list does not.
var _cancel_press := UiCancelPress.new()


func _ready() -> void:
	super._ready()
	_start_music_once()
	animation_state_machine = $MenuAnimationTree.get("parameters/playback")
	_saved_tournament = Tournament.load_saved()


func _input(event: InputEvent) -> void:
	if _cancel_press.is_unpaired_release(event):
		return
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
	# The closing sub menu must not close the menu opened in its place when it leaves the tree.
	if sub_menu:
		# One-shot connections are already gone once their signal was emitted.
		for closing_signal: Signal in [sub_menu.hidden, sub_menu.tree_exiting]:
			if closing_signal.is_connected(_close_sub_menu):
				closing_signal.disconnect(_close_sub_menu)
	super._close_sub_menu()
	animation_state_machine.travel("OpenMainMenu")
	if _return_to_modes:
		_return_to_modes = false
		_open_modes_menu()


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


func _on_modes_button_pressed() -> void:
	_open_modes_menu()


func _open_modes_menu() -> void:
	var modes: ModesMenu = _open_sub_menu(modes_packed_scene)
	modes.setup(_saved_tournament != null)
	modes.tournament_requested.connect(_open_from_modes.bind(_start_tournament_select))
	modes.training_requested.connect(_open_from_modes.bind(_start_training_select))
	modes.continue_tournament_requested.connect(_continue_tournament)


## Replaces the modes menu by the menu `open` opens; closing that returns to the modes menu.
func _open_from_modes(open: Callable) -> void:
	_close_sub_menu()
	_return_to_modes = true
	open.call()


func _start_tournament_select() -> void:
	_open_sub_menu(tournament_select_packed_scene).selection_confirmed.connect(
		_load_mode_scene.bind(tournament_scene_path)
	)


func _start_training_select() -> void:
	_open_sub_menu(training_select_packed_scene).selection_confirmed.connect(
		_load_mode_scene.bind(training_scene_path)
	)


## Starts the mode picked from the modes menu: the menu closing as the scene changes must not
## open the modes menu again.
func _load_mode_scene(scene_path: String) -> void:
	_return_to_modes = false
	SceneLoader.load_scene(scene_path)


## Continues the saved tournament, played with the first connected device.
func _continue_tournament() -> void:
	GlobalGameData.continue_tournament(_saved_tournament, InputDevice.get_connected_device_ids()[0])
	SceneLoader.load_scene(tournament_scene_path)
