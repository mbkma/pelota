extends Control
class_name PlayerSelector

signal selection_changed

const SPRITE_PATH: String = "res://assets/textures/players/"

@onready var selector = $Selector
@onready var ranking = selector.get_node("Ranking")
@onready var next_button = selector.get_node("Buttons/Next")
@onready var prev_button = selector.get_node("Buttons/Prev")
@onready var input_select_button = selector.get_node("Input/InputSelectButton")
@onready var ready_button = selector.get_node("Ready")
@onready var check_button = $CheckButton

@export var player_selected = false
@export var player_index: int = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	next_button.pressed.connect(on_button_pressed.bind("Button_Next"))
	prev_button.pressed.connect(on_button_pressed.bind("Button_Prev"))
	check_button.pressed.connect(on_button_pressed.bind("Button_Check"))
	ready_button.pressed.connect(on_button_ready_pressed)
	input_select_button.get_popup().id_pressed.connect(on_input_select_button_pressed)

	player_changed()


func player_changed():
	var data = GlobalGameData.player_data[player_index]
	ranking.player_name.text = data.first_name + "\n" + data["last_name"]
	ranking.rank.text = str(data["rank"])
	if ResourceLoader.exists(SPRITE_PATH + data["last_name"].to_lower() + ".png"):
		ranking.player_image.texture = load(SPRITE_PATH + data["last_name"].to_lower() + ".png")


func on_button_ready_pressed():
	check_button.visible = true
	player_selected = true
	emit_signal("selection_changed")


func on_button_pressed(button_name):
	if button_name == "Button_Next":
		player_index = (player_index + 1) % GlobalGameData.player_data.size()
		player_changed()
	elif button_name == "Button_Prev":
		player_index = (player_index - 1) % GlobalGameData.player_data.size()
		player_changed()
	elif button_name == "Button_Check":
		check_button.visible = false
		player_selected = false
		emit_signal("selection_changed")


func on_input_select_button_pressed(id):
	if id == 0:  # keyboard
		input_select_button.text = "Keyboard"
	elif id == 1:  # controller
		input_select_button.text = "Controller"
	elif id == 2:  # cpu
		input_select_button.text = "CPU"
