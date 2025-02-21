extends Node3D

@onready var speed_label: Label3D = $Speed


func _ready() -> void:
	speed_label.visible = false

# @speed is serve speed in meters per second
func show_serve_speed(speed: int):
	await get_tree().create_timer(randf_range(1, 2)).timeout
	speed_label.show()
	speed *= 2.23  # convert to mph
	speed_label.text = str(speed)
	await get_tree().create_timer(5).timeout
	speed_label.hide()
