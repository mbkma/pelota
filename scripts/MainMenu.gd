extends Control

# Called when the scene is loaded
func _ready():
	# Connect button signals
	$VBoxContainer/NewGameButton.pressed.connect(self._on_new_game_button_pressed)
	$VBoxContainer/Settings.pressed.connect(self._on_settings_button_pressed)
	$VBoxContainer/ExitButton.pressed.connect(self._on_exit_button_pressed)

# Start a new game
func _on_new_game_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Game.tscn")  # Replace with the path to your Game scene

# Show the settings screen
func _on_settings_button_pressed():
	show_settings()

# Exit the game
func _on_exit_button_pressed():
	get_tree().quit()

# Function to show settings (you can extend this as needed)
func show_settings():
	var settings_popup = Popup.new()
	settings_popup.popup_centered(Vector2(400, 300))  # Adjust size as needed
	settings_popup.add_child(Label.new())
	settings_popup.get_child(0).text = "settings: Use the arrow keys to move, Z to hit, X to slice, and space to serve."
	add_child(settings_popup)
