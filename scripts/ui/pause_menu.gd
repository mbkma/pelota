## Pause menu that can be toggled with ESC key
class_name PauseMenu
extends Control

@onready var pause_panel: Panel = $PausePanel
@onready var resume_button: Button = $PausePanel/VBoxContainer/ResumeButton
@onready var main_menu_button: Button = $PausePanel/VBoxContainer/MainMenuButton

var is_paused: bool = false


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

	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)


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
	Loggie.msg("[PauseMenu] Game paused").debug()


## Resume the game
func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()
	Loggie.msg("[PauseMenu] Game resumed").debug()


## Handle resume button press
func _on_resume_pressed() -> void:
	resume_game()


## Handle main menu button press
func _on_main_menu_pressed() -> void:
	# Unpause before changing scene
	get_tree().paused = false
	is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Switch to main menu using the scene manager
	SceneManager.goto(load("res://scenes/ui/main_menu.tscn"))
