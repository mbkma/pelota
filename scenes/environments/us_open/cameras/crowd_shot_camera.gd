## Broadcast camera at court level that shows the crowd between points: a few rows of spectators
## across the court in a long-lens shot, panning slowly along them.
class_name CrowdShotCamera
extends Camera3D

## Distance (m) of the spectators it shows (nearest, farthest), and how squarely (cosine of the
## angle) their seats face it at least
const SEAT_DISTANCE: Vector2 = Vector2(20.0, 45.0)
const MIN_FACING: float = 0.8
## Seats straight across the court (|z| below it, m) are hidden behind the umpire's chair
const MIN_SIDEWAYS: float = 3.0
## Height (m) above a seat's floor of a seated spectator's head, and how much (m) of the crowd the
## shot shows from top to bottom
const HEAD_HEIGHT: float = 1.1
const FRAME_HEIGHT: float = 4.0
## How fast (degrees/s) the camera pans along the crowd
const PAN_SPEED: float = 0.8

## Seats of the stadium the crowd sits on
@export var seating: StadiumSeating

## Heads of the spectators the camera can show, found on the first shot
var _heads := PackedVector3Array()
## Pan (degrees/s, either way) of the current shot
var _pan: float = 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not current:
		set_process(false)
		return
	global_rotate(Vector3.UP, deg_to_rad(_pan) * delta)


## Cuts to a few spectators picked at random, and pans slowly along them while on air.
func frame_spectators() -> void:
	if _heads.is_empty():
		_heads = _heads_in_view()
	var head: Vector3 = _heads[randi() % _heads.size()]
	look_at(head, Vector3.UP)
	fov = rad_to_deg(2.0 * atan(FRAME_HEIGHT * 0.5 / global_position.distance_to(head)))
	_pan = PAN_SPEED * (1.0 if randf() < 0.5 else -1.0)
	set_process(true)


## Heads of the spectators whose seats face the camera from across the court.
func _heads_in_view() -> PackedVector3Array:
	var heads := PackedVector3Array()
	for section in seating.sections:
		for seat in section:
			var head := Vector3(seat.x, seat.y + HEAD_HEIGHT, seat.z)
			var to_camera: Vector3 = global_position - head
			var distance: float = to_camera.length()
			var facing: Vector3 = Basis(Vector3.UP, seat.w) * Vector3.BACK
			if (
				distance >= SEAT_DISTANCE.x
				and distance <= SEAT_DISTANCE.y
				and absf(seat.z) >= MIN_SIDEWAYS
				and facing.dot(to_camera / distance) >= MIN_FACING
			):
				heads.append(head)
	assert(not heads.is_empty(), "No seats in view of %s" % name)
	return heads
