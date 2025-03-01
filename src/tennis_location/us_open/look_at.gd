extends Node3D

@export var target: Node3D


func _process(delta: float) -> void:
	if target:
		look_at(target.global_position)
		rotation.x = 0
		rotation.z = 0
