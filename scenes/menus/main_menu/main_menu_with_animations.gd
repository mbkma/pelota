extends MainMenu
## Main menu extension: animates the title and menu fading in (the player can skip it with
## any input), starts the music, opens the how-to-play screen and the player select before
## a new match.

## Player select opened by 'New Game'; confirming it starts the match.
@export var player_select_packed_scene: PackedScene
## Plays the music (a random song per game launch) and keeps running across scenes.
@export var music_director_scene: PackedScene
## How-to-play screen opened by the 'How to Play' button.
@export var tutorial_packed_scene: PackedScene

var animation_state_machine: AnimationNodeStateMachinePlayback


func _ready() -> void:
	super._ready()
	_start_music_once()
	animation_state_machine = $MenuAnimationTree.get("parameters/playback")


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
		or _event_is_mouse_button_released(event)
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
