@tool
class_name CrowdConfig
extends Resource

## Configuration for the crowd system
## This resource centralizes all crowd system parameters for better editor experience and flexibility

## Grid layout configuration
## Number of rows in the crowd grid
@export var grid_rows: int = 10:
	set(new_setting):
		grid_rows = new_setting
		changed.emit()

## Number of columns in the crowd grid
@export var grid_columns: int = 4:
	set(new_setting):
		grid_columns = new_setting
		changed.emit()

## Spacing between crowd members on X axis (left/right)
@export var seat_spacing_x: float = 0.7:
	set(new_setting):
		seat_spacing_x = new_setting
		changed.emit()

## Spacing between crowd members on Y axis (up/down)
@export var seat_spacing_y: float = 0.29:
	set(new_setting):
		seat_spacing_y = new_setting
		changed.emit()

## Spacing between crowd members on Z axis (depth)
@export var seat_spacing_z: float = 1.029:
	set(new_setting):
		seat_spacing_z = new_setting
		changed.emit()

## Animation configuration
## Time to blend between animations (seconds)
@export var animation_blend_time: float = 0.5:
	set(new_setting):
		animation_blend_time = new_setting
		changed.emit()

## Whether to randomly seek into animations for variety
@export var animation_seek_enabled: bool = true:
	set(new_setting):
		animation_seek_enabled = new_setting
		changed.emit()

## Idle animation names to randomly play
@export var idle_animations: PackedStringArray = [
	"sit-idle-2",
	"sit-idle-3",
	"sit-talk-1",
	"sit-talk-2",
	"sit-talk-3",
]:
	set(new_setting):
		idle_animations = new_setting
		changed.emit()

## Victory animation names to play when crowd celebrates
@export var victory_animations: PackedStringArray = [
	"sit-victory-1",
	"sit-victory-2",
	"sit-victory-3",
	"sit-victory-4",
]:
	set(new_setting):
		victory_animations = new_setting
		changed.emit()

## Character model variants to randomly select from
@export var model_variants: PackedStringArray = [
	"crowd-1",
	#"crowd-2",
	"crowd-3",
	"crowd-4",
]:
	set(new_setting):
		model_variants = new_setting
		changed.emit()

## File paths for each model variant
@export var model_paths: Dictionary = {
	"crowd-1": "res://assets/models/crowd/crowd-1.blend",
	"crowd-2": "res://assets/models/crowd/crowd-2.blend",
	"crowd-3": "res://assets/models/crowd/crowd-3.blend",
	"crowd-4": "res://assets/models/crowd/crowd-4.blend",
}:
	set(new_setting):
		model_paths = new_setting
		changed.emit()

## Animation configuration
## Percentage of crowd members that will be animated (0.0 to 1.0, where 0.5 = 50% of crowd animates)
@export var animation_percentage: float = 1.0:
	set(new_setting):
		animation_percentage = clamp(new_setting, 0.0, 1.0)
		changed.emit()

## Audio configuration
## Background crowd noise sounds to play during idle
@export var idle_sounds: Array[AudioStream] = []:
	set(new_setting):
		idle_sounds = new_setting
		changed.emit()

## Crowd celebration sounds to play after scoring
@export var after_point_sounds: Array[AudioStream] = []:
	set(new_setting):
		after_point_sounds = new_setting
		changed.emit()

## Color palette for crowd member variations
@export var color_palette: CrowdColorPalette:
	set(new_setting):
		color_palette = new_setting
		changed.emit()

## Performance configuration
## Enable/disable signal cleanup for animation state machines
@export var signal_cleanup_enabled: bool = true:
	set(new_setting):
		signal_cleanup_enabled = new_setting
		changed.emit()

## Enable/disable frustum culling for off-screen crowd members
@export var culling_enabled: bool = true:
	set(new_setting):
		culling_enabled = new_setting
		changed.emit()

## Apply random color variations to crowd member clothing and appearance
@export var apply_color_variations: bool = true:
	set(new_setting):
		apply_color_variations = new_setting
		changed.emit()

## Get a random model variant name
func get_random_model_variant() -> String:
	if model_variants.is_empty():
		return "crowd-1"
	return model_variants[randi() % model_variants.size()]

## Get random idle animation
func get_random_idle_animation() -> String:
	if idle_animations.is_empty():
		return ""
	return idle_animations[randi() % idle_animations.size()]

## Get random victory animation
func get_random_victory_animation() -> String:
	if victory_animations.is_empty():
		return ""
	return victory_animations[randi() % victory_animations.size()]

## Get a random idle sound
func get_random_idle_sound() -> AudioStream:
	if idle_sounds.is_empty():
		return null
	return idle_sounds[randi() % idle_sounds.size()]

## Get a random after-point sound
func get_random_after_point_sound() -> AudioStream:
	if after_point_sounds.is_empty():
		return null
	return after_point_sounds[randi() % after_point_sounds.size()]

## Validate configuration
func validate() -> bool:
	if grid_rows <= 0 or grid_columns <= 0:
		push_error("CrowdConfig: Invalid grid dimensions")
		return false
	if idle_animations.is_empty():
		push_warning("CrowdConfig: No idle animations configured")
	if model_variants.is_empty():
		push_error("CrowdConfig: No model variants configured")
		return false

	# Ensure color palette exists
	if not color_palette:
		color_palette = CrowdColorPalette.new()

	return true


## Get the color palette, creating one if needed
func get_color_palette() -> CrowdColorPalette:
	if not color_palette:
		color_palette = CrowdColorPalette.new()
	return color_palette
