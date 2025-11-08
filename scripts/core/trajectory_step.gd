class_name TrajectoryStep
extends RefCounted

var point: Vector3
var time: float


func _init(point: Vector3, time: float) -> void:
	self.point = point
	self.time = time
