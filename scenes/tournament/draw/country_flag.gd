## A small flag of a player's country on the draw, the country's file in FLAG_DIR.
@tool
class_name CountryFlag
extends TextureRect

## The flags, one per country, named by its three-letter code (e.g. "ITA.svg")
const FLAG_DIR: String = "res://assets/textures/flags/"

## Three-letter code of the country (PlayerData.country_code)
@export var country_code: String = "":
	set(value):
		country_code = value
		texture = load(FLAG_DIR + value + ".svg") if not value.is_empty() else null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK, false, 2.0)
