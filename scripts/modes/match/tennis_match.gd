extends Node

signal level_changed(level_name, init_data)

@onready var pause_menu = $PauseMenu


func to_main_menu():
	#SceneManager.swap_scenes("res://src/ui/menus/main_menu.tscn")
	level_changed.emit(load("res://src/ui/main_menu.tscn"))
