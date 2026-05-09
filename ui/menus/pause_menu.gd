## Pause menu that can be toggled with ESC key
class_name PauseMenu
extends Control

@onready var pause_panel: Panel = $PausePanel
@onready var replay_mode_button: Button = $PausePanel/VBoxContainer/ReplayModeButton
@onready var resume_button: Button = $PausePanel/VBoxContainer/ResumeButton
@onready var main_menu_button: Button = $PausePanel/VBoxContainer/MainMenuButton

var is_paused: bool = false
var _match_manager: MatchManager


func _ready() -> void:
	# Set process mode to always receive input
	# This allows us to receive ESC input both when running and when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide pause menu initially
	hide()

	# Reset pause state to make sure we're not in a paused state
	is_paused = false
	if get_tree().paused:
		get_tree().paused = false

	_match_manager = get_parent().get_node_or_null("MatchManager") as MatchManager

	# Connect button signal
	replay_mode_button.pressed.connect(_on_replay_mode_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	if _match_manager and not _match_manager.replay_started.is_connected(_on_replay_started):
		_match_manager.replay_started.connect(_on_replay_started)


func _input(event: InputEvent) -> void:
	# Toggle pause menu with ESC key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_tree().root.set_input_as_handled()


## Toggle pause on/off
func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


## Pause the game
func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	Loggie.msg("Game paused").info()


## Resume the game
func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	# Only capture mouse if both players are using gamepads
	if HumanController.should_capture_mouse():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hide()
	Loggie.msg("Game resumed").info()


func _on_replay_mode_pressed() -> void:
	if not _match_manager:
		return

	if _match_manager.has_replay() or _match_manager.load_replay_from_disk():
		_match_manager.start_replay()
		_match_manager.pause_replay()
		is_paused = false
		hide()


func _on_replay_started(_duration_seconds: float) -> void:
	is_paused = false
	hide()


func _on_resume_pressed() -> void:
	resume_game()


func _on_main_menu_pressed() -> void:
	# Unpause before changing scene
	get_tree().paused = false
	is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Switch to main menu using the scene manager
	SceneManager.goto(load("res://ui/menus/main_menu.tscn"))
