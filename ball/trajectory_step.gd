class_name TrajectoryStep
extends RefCounted

var point: Vector3
var time: float
var bounces: int

func _init(point: Vector3, time: float, bounces: int) -> void:
	self.point = point
	self.time = time
	self.bounces = bounces
