## Camera slowly circling the court for the menu background, gently varying its distance and
## height so the view keeps changing.
class_name MenuCameraOrbit
extends Camera3D

## Point the camera looks at
@export var focus: Vector3 = Vector3(0.0, 0.5, 0.0)
@export var radius: float = 24.0
@export var radius_variation: float = 6.0
@export var height: float = 7.0
@export var height_variation: float = 3.0
## Orbit speed (radians per second)
@export var angular_speed: float = 0.05

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	var angle: float = _time * angular_speed
	var distance: float = radius + sin(_time * 0.11) * radius_variation
	var elevation: float = height + sin(_time * 0.07 + 1.3) * height_variation
	global_position = focus + Vector3(cos(angle) * distance, elevation, sin(angle) * distance)
	look_at(focus, Vector3.UP)
