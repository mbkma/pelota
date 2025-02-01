extends Node3D

@onready var speed_label: Label3D = $Speed


# @speed is serve speed in meters per second
func show_serve_speed(speed: int):
	await get_tree().create_timer(randf_range(1, 2)).timeout

	speed *= 2.23  # convert to mph
	speed_label.text = str(speed)
