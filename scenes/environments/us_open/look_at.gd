## Turns (around the vertical axis only) to face its target, e.g. a TV camera following a player.
## It turns after the target smoothly, like a camera operator, also when the target changes.
class_name TargetTracker
extends Node3D

@export var target: Node3D
## How quickly (1/s) it turns after its target
@export var turn_rate: float = 5.0


func _process(delta: float) -> void:
	if target:
		var to_target: Vector3 = target.global_position - global_position
		var yaw: float = atan2(-to_target.x, -to_target.z)
		var weight: float = 1.0 - exp(-turn_rate * delta)
		global_rotation = Vector3(0.0, lerp_angle(global_rotation.y, yaw, weight), 0.0)
