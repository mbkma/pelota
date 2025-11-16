class_name CrowdConfig
extends Resource

## Configuration for the crowd system
## This resource centralizes all crowd system parameters for better editor experience and flexibility

## Grid layout configuration
@export var grid_rows: int = 10
@export var grid_columns: int = 4
@export var seat_spacing_x: float = 0.7
@export var seat_spacing_y: float = 0.29
@export var seat_spacing_z: float = 1.029

## Animation configuration
@export var animation_blend_time: float = 0.5
@export var animation_seek_enabled: bool = true

## Idle animation names
@export var idle_animations: PackedStringArray = [
	"sit-idle-2",
	"sit-idle-3",
	"sit-talk-1",
	"sit-talk-2",
	"sit-talk-3",
]

## Victory animation names
@export var victory_animations: PackedStringArray = [
	"sit-victory-1",
	"sit-victory-2",
	"sit-victory-3",
	"sit-victory-4",
]

## Model variant names - keys for the people dictionary
@export var model_variants: PackedStringArray = [
	"crowd-1",
	#"crowd-2",
	"crowd-3",
	"crowd-4",
]

## Model resources - path to load from
@export var model_paths: Dictionary = {
	"crowd-1": "res://assets/models/crowd/crowd-1.blend",
	"crowd-2": "res://assets/models/crowd/crowd-2.blend",
	"crowd-3": "res://assets/models/crowd/crowd-3.blend",
	"crowd-4": "res://assets/models/crowd/crowd-4.blend",
}

## LOD (Level of Detail) configuration
@export var lod_enabled: bool = true
@export var lod_distance_high: float = 20.0  # Full quality animations
@export var lod_distance_medium: float = 50.0  # Some idle animations skipped
@export var lod_distance_low: float = 100.0  # Minimal animation updates

## LOD animation reduction factors (0.0 to 1.0)
@export var lod_medium_animation_chance: float = 0.5  # Play 50% of animations
@export var lod_low_animation_chance: float = 0.1  # Play 10% of animations

## Audio configuration
@export var idle_sounds: Array[AudioStream] = []
@export var after_point_sounds: Array[AudioStream] = []

## Color palette for crowd member variations
@export var color_palette: CrowdColorPalette

## Performance configuration
@export var signal_cleanup_enabled: bool = true
@export var culling_enabled: bool = true
@export var apply_color_variations: bool = true

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

## Determine LOD level based on distance from camera
func get_lod_level(distance: float) -> int:
	if not lod_enabled:
		return 0  # High quality
	if distance < lod_distance_high:
		return 0  # High quality
	elif distance < lod_distance_medium:
		return 1  # Medium quality
	else:
		return 2  # Low quality

## Get animation chance based on LOD level (0.0 to 1.0)
func get_animation_chance(lod_level: int) -> float:
	match lod_level:
		0:
			return 1.0
		1:
			return lod_medium_animation_chance
		2:
			return lod_low_animation_chance
		_:
			return 1.0

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
	return true
