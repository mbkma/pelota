class_name TrajectoryStep
extends RefCounted

var point: Vector3
var time: float
var bounces: int

func _init(p_point: Vector3, p_time: float, p_bounces: int) -> void:
	point = p_point
	time = p_time
	bounces = p_bounces


## Whether a stroke at this step is a volley: close to the net, before the ball bounces.
func is_volley_contact() -> bool:
	return bounces == 0 and absf(point.z) < GameConstants.NET_ZONE_DEPTH
