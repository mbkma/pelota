extends Node

signal level_changed(level_name, init_data)

var player


func _ready() -> void:
	$CareerMainMenu/NextDay.pressed.connect(_on_NextDay_pressed)


func init_scene(init_data: Dictionary):
	player = init_data.player


func _on_NextDay_pressed() -> void:
	pass
