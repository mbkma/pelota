class_name TrajectoryStep
extends RefCounted

var point: Vector3
var time: float
var bounces: int


func _init(p_point: Vector3, p_time: float, p_bounces: int) -> void:
	point = p_point
	time = p_time
	bounces = p_bounces


## Whether a stroke at this step is a volley: the ball is taken out of the air, before it
## bounces.
func is_volley_contact() -> bool:
	return bounces == 0


## Whether the step lies in the net zone, where players volley instead of letting the ball
## bounce.
func is_in_net_zone() -> bool:
	return absf(point.z) < GameConstants.NET_ZONE_DEPTH
