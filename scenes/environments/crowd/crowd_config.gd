@tool
class_name CrowdConfig
extends Resource
## Layout, models, animations and colors of a crowd block.

## Rows and columns of spectators in the block
@export var grid_rows: int = 10:
	set(value):
		grid_rows = value
		emit_changed()
@export var grid_columns: int = 4:
	set(value):
		grid_columns = value
		emit_changed()

## Seat spacing (m): sideways (x), up per row (y), back per row (z)
@export var seat_spacing: Vector3 = Vector3(0.7, 0.29, 1.029):
	set(value):
		seat_spacing = value
		emit_changed()

## Time to blend between animations (seconds)
@export var animation_blend_time: float = 0.5
## Whether idle animations start at a random point for variety
@export var animation_seek_enabled: bool = true
## Idle animations played at random
@export var idle_animations: PackedStringArray = []
## Animations played when the crowd cheers
@export var victory_animations: PackedStringArray = []
## Share of spectators that move (0.0 to 1.0); the others hold a still idle pose, which costs
## nothing per frame. Lower it for large crowds.
@export_range(0.0, 1.0, 0.01) var animation_percentage: float = 0.3

## Spectator models (each with an AnimationPlayer holding the animations above)
@export var models: Array[PackedScene] = []:
	set(value):
		models = value
		emit_changed()

## Colors spectators' clothes, hair and skin are tinted with
@export var color_palette: CrowdColorPalette:
	set(value):
		color_palette = value
		emit_changed()
