extends Node

signal level_changed(level_name, init_data)

@onready var pause_menu = $PauseMenu

func to_main_menu():
	level_changed.emit(load("res://src/ui/main_menu.tscn"))
