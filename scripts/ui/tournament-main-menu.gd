extends Control

signal level_changed(level_name, init_data)

@onready var next_round_button = $Button
@onready var grid = $GridContainer

@onready var tournament = Tournament.new()
@export var match_panel: PackedScene

func _ready() -> void:
	next_round_button.pressed.connect(_on_NextRoundButton_pressed)

	for m in tournament.singles_matches:
		var mp = match_panel.instantiate()
		grid.add_child(mp)
		mp.setup(m)


func _on_NextRoundButton_pressed() -> void:
	tournament.next_round()
	next_round_button.disabled = true
