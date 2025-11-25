@tool
class_name CrowdColorPalette
extends Resource

## Color palette for realistic crowd member clothing and appearance variations

## Shirt colors - realistic athletic wear colors
@export var shirt_colors: PackedColorArray = [
	Color.WHITE,
	Color(0.9, 0.9, 0.9),  # Off-white
	Color(0.2, 0.2, 0.2),  # Dark gray
	Color(0.4, 0.4, 0.4),  # Medium gray
	Color(0.1, 0.3, 0.6),  # Navy blue
	Color(0.2, 0.5, 0.8),  # Light blue
	Color(0.8, 0.2, 0.2),  # Red
	Color(0.8, 0.4, 0.1),  # Orange
	Color(0.2, 0.6, 0.2),  # Green
	Color(0.6, 0.2, 0.4),  # Purple
]:
	set(new_setting):
		shirt_colors = new_setting
		changed.emit()

## Shorts colors - realistic casual/athletic wear
@export var shorts_colors: PackedColorArray = [
	Color(0.2, 0.2, 0.2),  # Black
	Color(0.3, 0.3, 0.3),  # Dark gray
	Color(0.5, 0.5, 0.5),  # Medium gray
	Color(0.8, 0.8, 0.8),  # Light gray
	Color(0.1, 0.3, 0.6),  # Navy blue
	Color(0.2, 0.5, 0.8),  # Light blue
	Color(0.4, 0.3, 0.2),  # Brown
	Color(0.8, 0.2, 0.2),  # Red
	Color(0.2, 0.6, 0.2),  # Green
]:
	set(new_setting):
		shorts_colors = new_setting
		changed.emit()

## Hair colors - realistic human hair variations
@export var hair_colors: PackedColorArray = [
	Color(0.1, 0.08, 0.05),  # Black
	Color(0.2, 0.15, 0.08),  # Dark brown
	Color(0.35, 0.25, 0.1),  # Brown
	Color(0.5, 0.35, 0.15),  # Light brown
	Color(0.6, 0.45, 0.2),   # Blonde
	Color(0.55, 0.3, 0.15),  # Auburn
	Color(0.25, 0.2, 0.18),  # Dark gray
	Color(0.4, 0.35, 0.32),  # Light gray
]:
	set(new_setting):
		hair_colors = new_setting
		changed.emit()

## Skin tone variations - realistic human skin tones
@export var skin_colors: PackedColorArray = [
	Color(0.95, 0.85, 0.75),  # Very light
	Color(0.92, 0.82, 0.72),  # Light
	Color(0.88, 0.75, 0.62),  # Light-medium
	Color(0.85, 0.68, 0.52),  # Medium
	Color(0.75, 0.55, 0.4),   # Medium-dark
	Color(0.65, 0.45, 0.3),   # Dark
]:
	set(new_setting):
		skin_colors = new_setting
		changed.emit()

## Get a random shirt color
func get_random_shirt_color() -> Color:
	if shirt_colors.is_empty():
		return Color.WHITE
	return shirt_colors[randi() % shirt_colors.size()]

## Get a random shorts color
func get_random_shorts_color() -> Color:
	if shorts_colors.is_empty():
		return Color(0.2, 0.2, 0.2)
	return shorts_colors[randi() % shorts_colors.size()]

## Get a random hair color
func get_random_hair_color() -> Color:
	if hair_colors.is_empty():
		return Color(0.1, 0.08, 0.05)
	return hair_colors[randi() % hair_colors.size()]

## Get a random skin color
func get_random_skin_color() -> Color:
	if skin_colors.is_empty():
		return Color(0.92, 0.82, 0.72)
	return skin_colors[randi() % skin_colors.size()]
