extends Node

@onready var pause_menu = $PauseMenu

func to_main_menu():
	SceneManager.goto(load("res://scenes/ui/main_menu.tscn"))
