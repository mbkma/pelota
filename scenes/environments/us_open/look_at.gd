## Turns (around the vertical axis only) to face its target, e.g. a TV camera following a player.
class_name TargetTracker
extends Node3D

@export var target: Node3D


func _process(_delta: float) -> void:
	if target:
		look_at(target.global_position)
		rotation.x = 0
		rotation.z = 0
