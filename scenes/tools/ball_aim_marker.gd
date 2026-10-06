## Ground marker for where a stroke is aimed. The disc shows the radius in which the ball
## may land; the dot marks the aim point itself.
class_name BallAimMarker
extends Node3D

## Radius used when a controller does not report an uncertainty.
const DEFAULT_RADIUS: float = 0.3

@export var normal_color: Color = Color(0.25, 0.37, 0.0, 0.45)
@export var highlight_color: Color = Color(1.0, 0.8, 0.1, 0.6)

@onready var _area: MeshInstance3D = $Area
@onready var _area_material: StandardMaterial3D = _area.get_active_material(0)


## Sets the landing uncertainty radius in meters.
func set_radius(radius: float) -> void:
	_area.scale = Vector3(radius, 1.0, radius)


## Highlights the marker, e.g. for a perfectly timed stroke.
func set_highlighted(highlighted: bool) -> void:
	_area_material.albedo_color = highlight_color if highlighted else normal_color
