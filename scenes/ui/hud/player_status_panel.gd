## Corner panel showing a player's stamina, pressure and confidence.
class_name PlayerStatusPanel
extends PanelContainer

@export var player: Player
@export var name_color: Color = Palette.CREAM

@onready var _name_label: Label = %NameLabel
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _pressure_bar: ProgressBar = %PressureBar
@onready var _confidence_bar: ProgressBar = %ConfidenceBar


func _ready() -> void:
	_name_label.text = player.player_data.last_name
	_name_label.add_theme_color_override("font_color", name_color)


func _process(_delta: float) -> void:
	_stamina_bar.value = player.get_stamina_ratio()
	_pressure_bar.value = player.mental_state.pressure
	_confidence_bar.value = player.mental_state.confidence
