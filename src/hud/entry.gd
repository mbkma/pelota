class_name Entry
extends HBoxContainer

@onready var left: Label = $Desc
@onready var right: Label = $Cont


func update(text):
	right.text = str(text)
	right.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.1).timeout
	right.remove_theme_color_override("font_color")
