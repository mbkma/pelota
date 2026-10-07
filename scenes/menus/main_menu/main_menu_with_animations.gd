extends MainMenu
## Main menu extension that adds options and animates the title and menu fading in.
## The scene adds a 'Continue' button if a game is in progress.
## The animation can be skipped by the player with any input.

## Optional scene to open when the player clicks a 'Player Select' button.
@export var player_select_packed_scene: PackedScene
## If true, have the player confirm before starting a new game if a game is in progress.
@export var confirm_new_game : bool = true
## Plays the music (a random song per game launch) and keeps running across scenes.
@export var music_director_scene: PackedScene
## How-to-play screen opened by the 'How to Play' button.
@export var tutorial_packed_scene: PackedScene

var animation_state_machine : AnimationNodeStateMachinePlayback

@onready var continue_game_button = %ContinueGameButton
@onready var new_game_confirmation = %NewGameConfirmation

func load_game_scene() -> void:
	GameState.start_game()
	super.load_game_scene()

func _start_new_game_flow() -> void:
	GameState.reset()
	if player_select_packed_scene == null:
		load_game_scene()
		return
	var player_select_scene := _open_sub_menu(player_select_packed_scene)
	if player_select_scene.has_signal("selection_confirmed"):
		player_select_scene.connect("selection_confirmed", load_game_scene)
	else:
		load_game_scene()

func new_game() -> void:
	if confirm_new_game and continue_game_button.visible:
		new_game_confirmation.show()
	else:
		_start_new_game_flow()

func intro_done() -> void:
	animation_state_machine.travel("OpenMainMenu")

func _is_in_intro() -> bool:
	return animation_state_machine.get_current_node() == "Intro"

func _event_skips_intro(event : InputEvent) -> bool:
	return event.is_action_released("ui_accept") or \
		event.is_action_released("ui_select") or \
		event.is_action_released("ui_cancel") or \
		_event_is_mouse_button_released(event)

func _open_sub_menu(menu : PackedScene) -> Node:
	animation_state_machine.travel("OpenSubMenu")
	return super._open_sub_menu(menu)

func _close_sub_menu() -> void:
	super._close_sub_menu()
	animation_state_machine.travel("OpenMainMenu")

func _input(event : InputEvent) -> void:
	if _is_in_intro() and _event_skips_intro(event):
		intro_done()
		return
	super._input(event)


func _show_continue_if_set() -> void:
	if GameState.get_current_level_path().is_empty(): return
	continue_game_button.show()

func _ready() -> void:
	super._ready()
	_start_music_once()
	_show_continue_if_set()
	animation_state_machine = $MenuAnimationTree.get("parameters/playback")

func _on_continue_game_button_pressed() -> void:
	GameState.continue_game()
	load_game_scene()

## Starts the music director the first time the main menu opens; afterwards (e.g. back from a
## match) resumes the music.
func _start_music_once() -> void:
	var director: MusicDirector = get_tree().root.get_node_or_null(^"MusicDirector")
	if director:
		director.resume()
		return
	get_tree().root.add_child.call_deferred(music_director_scene.instantiate())


func _on_new_game_confirmation_confirmed() -> void:
	_start_new_game_flow()


func _on_how_to_play_button_pressed() -> void:
	_open_sub_menu(tutorial_packed_scene)
