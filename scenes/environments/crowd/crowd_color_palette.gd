@tool
class_name CrowdColorPalette
extends Resource
## Colors for crowd member clothing and appearance variations.

@export var shirt_colors: PackedColorArray = []
@export var shorts_colors: PackedColorArray = []
@export var hair_colors: PackedColorArray = []
@export var skin_colors: PackedColorArray = []


static func pick(colors: PackedColorArray) -> Color:
	return colors[randi() % colors.size()]
