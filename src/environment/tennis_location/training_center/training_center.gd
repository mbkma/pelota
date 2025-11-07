extends Node3D

signal level_changed(level_name, init_data)


func _ready() -> void:
	print("training center global basis", global_basis)
	print("training center local basis", basis)
