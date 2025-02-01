extends Control

signal level_changed(level_name, init_data)

@onready var player_selector: PlayerSelector = $PlayerSelector


func _on_Button_pressed() -> void:
	pass
#	emit_signal("level_changed", "res://src/career/Career.tscn", {"player": new_player})
