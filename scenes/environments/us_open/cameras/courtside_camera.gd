## Broadcast camera low behind a baseline, centred on the court just over the back wall, operated
## like the baseline cameras of a real tennis broadcast (measured from US Open 2025 footage): it
## shows the court from behind the player on its end and pans after them, keeping them off centre
## towards their side so the court stays in the picture.
class_name CourtsideCamera
extends Camera3D

## Tilt (degrees) of the shot, looking down at the court
const TILT_DEGREES: float = -10.0
## Share of the angle to the player that the camera pans
const PAN_SHARE: float = 0.55
## How quickly (1/s) the camera turns after the player
const PAN_RATE: float = 3.0

## Player on this camera's end
var _player: Player


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _pan(), 1.0 - exp(-PAN_RATE * delta))


## Follows `player` (on this camera's end), cutting straight to them.
func follow(player: Player) -> void:
	_player = player
	rotation = Vector3(deg_to_rad(TILT_DEGREES), _pan(), 0.0)
	set_process(true)


func _pan() -> float:
	var to_player: Vector3 = _player.global_position - global_position
	var bearing: float = atan2(-to_player.x, -to_player.z)
	# Straight down the court, towards the net
	var ahead: float = atan2(global_position.x, global_position.z)
	return ahead + wrapf(bearing - ahead, -PI, PI) * PAN_SHARE
