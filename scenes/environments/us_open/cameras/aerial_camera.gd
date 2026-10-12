## Camera high above the stadium, like the airship camera of a real tennis broadcast: it looks
## down through the open roof at the court and slowly circles.
class_name AerialCamera
extends Camera3D

## Height (m) of the camera, and its distance (m) from above the court's centre: close enough that
## the court stays in sight through the opening of the roof
const HEIGHT: float = 120.0
const RADIUS: float = 30.0
## How fast (degrees/s) the camera circles
const ORBIT_SPEED: float = 2.0

## Where around the court (radians) the camera is
var _angle: float = 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not current:
		set_process(false)
		return
	_angle += deg_to_rad(ORBIT_SPEED) * delta
	_place()


## Cuts to the stadium from a random side, and circles while on air.
func frame_stadium() -> void:
	_angle = randf() * TAU
	_place()
	set_process(true)


func _place() -> void:
	global_position = Vector3(sin(_angle) * RADIUS, HEIGHT, cos(_angle) * RADIUS)
	look_at(Vector3.ZERO, Vector3.UP)
