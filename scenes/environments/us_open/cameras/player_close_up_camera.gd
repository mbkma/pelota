## Broadcast camera at court level that shows a player in close-up between points, with a long
## lens like the courtside cameras of a real tennis broadcast: head and upper body fill the
## picture, and it follows the player like an operator, with a little lag.
class_name PlayerCloseUpCamera
extends Camera3D

## Height (m) above the player's feet the shot is centred on, and how much (m) of the player it
## shows from top to bottom
const AIM_HEIGHT: float = 1.35
const FRAME_HEIGHT: float = 1.2
## How quickly (1/s) the camera turns and zooms after the player
const FOLLOW_RATE: float = 4.0

var _player: Player


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not current:
		set_process(false)
		return
	_aim(1.0 - exp(-FOLLOW_RATE * delta))


## Cuts to `player` and follows them while the camera is on air.
func frame(player: Player) -> void:
	_player = player
	_aim(1.0)
	set_process(true)


## Turns and zooms `weight` (0 to 1) of the way to the shot of the player.
func _aim(weight: float) -> void:
	var target: Vector3 = _player.global_position + Vector3.UP * AIM_HEIGHT
	var to_target: Vector3 = target - global_position
	global_basis = global_basis.slerp(Basis.looking_at(to_target), weight)
	var framed_fov: float = rad_to_deg(2.0 * atan(FRAME_HEIGHT * 0.5 / to_target.length()))
	fov = lerpf(fov, framed_fov, weight)
