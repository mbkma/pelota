## Broadcast TV camera at a fixed position, framed like the main camera of a real tennis
## broadcast (measured from US Open 2025 footage):
## - The match opens wider and tilted up toward the crowd, then zooms in and tilts down to the
##   standard shot.
## - Before a serve, when the returner is on this camera's end (standing far back), the camera
##   widens and tilts down a little to keep the returner in the picture. Shortly after the serve
##   it settles back to the standard shot.
## - It holds still during rallies and now and then reframes slightly between points.
class_name TvCamera
extends Camera3D

## Opening shot: how much wider (in screen size) and how far tilted up it starts
const OPENING_WIDEN: float = 1.2
const OPENING_TILT_UP_DEGREES: float = 2.5
const OPENING_DURATION: float = 5.0
## Return shot before a serve: how much wider and how far tilted down
const RETURN_WIDEN: float = 1.075
const RETURN_TILT_DOWN_DEGREES: float = 0.7
const RETURN_DURATION: float = 3.0
## Seconds after the serve before the camera settles back, and how long that takes
const SETTLE_DELAY: float = 1.0
const SETTLE_DURATION: float = 3.5
## Chance per point that the standard shot changes slightly
const REFRAME_CHANCE: float = 0.35
## Screen size of a reframed standard shot relative to the framed one (below 1 zooms in)
const REFRAME_ZOOM_MIN: float = 0.95
const REFRAME_ZOOM_MAX: float = 1.03
## Largest pan of a reframe to either side
const REFRAME_MAX_PAN_DEGREES: float = 0.6
const REFRAME_DURATION: float = 2.5

## Shot as set up in the scene
var _framed_fov: float
var _framed_rotation: Vector3
## Standard shot of the current point (the framed shot, maybe reframed)
var _standard_fov: float
var _standard_rotation: Vector3
## Whether the opening shot is still zooming in
var _opening: bool = false
## Whether the camera is in the shot widened for the returner
var _widened: bool = false
var _tween: Tween


func _ready() -> void:
	_framed_fov = fov
	_framed_rotation = rotation
	_standard_fov = fov
	_standard_rotation = rotation


## Starts wide and tilted up, then zooms in and tilts down to the standard shot.
func open_shot() -> void:
	fov = _widened_fov(_standard_fov, OPENING_WIDEN)
	rotation = _standard_rotation + Vector3(deg_to_rad(OPENING_TILT_UP_DEGREES), 0.0, 0.0)
	_widened = false
	_move_to(_standard_fov, _standard_rotation, OPENING_DURATION, Tween.EASE_OUT)
	_opening = true
	_tween.finished.connect(func() -> void: _opening = false)


## Sometimes changes the standard shot slightly. Call between points only.
func reframe() -> void:
	if randf() >= REFRAME_CHANCE:
		return
	_standard_fov = _framed_fov * randf_range(REFRAME_ZOOM_MIN, REFRAME_ZOOM_MAX)
	var pan: float = deg_to_rad(randf_range(-REFRAME_MAX_PAN_DEGREES, REFRAME_MAX_PAN_DEGREES))
	_standard_rotation = _framed_rotation + Vector3(0.0, pan, 0.0)
	_move_to(_standard_fov, _standard_rotation, REFRAME_DURATION, Tween.EASE_IN_OUT)


## Before a serve: widens and tilts down when the returner is on this camera's end.
## The opening shot is not interrupted.
func frame_return(receiver: Player) -> void:
	if _opening or signf(receiver.global_position.z) != signf(global_position.z):
		return
	_widened = true
	_move_to(
		_widened_fov(_standard_fov, RETURN_WIDEN),
		_standard_rotation - Vector3(deg_to_rad(RETURN_TILT_DOWN_DEGREES), 0.0, 0.0),
		RETURN_DURATION,
		Tween.EASE_IN_OUT
	)


## After the serve: settles back from the return shot to the standard shot.
func settle_after_serve() -> void:
	if not _widened:
		return
	_widened = false
	_move_to(_standard_fov, _standard_rotation, SETTLE_DURATION, Tween.EASE_IN_OUT, SETTLE_DELAY)


## Field of view that shows `widen` times as much in each screen direction.
func _widened_fov(base_fov: float, widen: float) -> float:
	return rad_to_deg(2.0 * atan(widen * tan(deg_to_rad(base_fov) / 2.0)))


func _move_to(
	target_fov: float,
	target_rotation: Vector3,
	duration: float,
	ease_type: Tween.EaseType,
	delay: float = 0.0
) -> void:
	if _tween:
		_tween.kill()
	_opening = false
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	_tween.tween_property(self, "fov", target_fov, duration).set_delay(delay)
	_tween.tween_property(self, "rotation", target_rotation, duration).set_delay(delay)
