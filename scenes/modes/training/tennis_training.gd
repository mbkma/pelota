extends Node


func _enter_tree() -> void:
	# The training player is controlled with the keyboard; set before the player creates its
	# controller.
	GlobalGameData.set_match_input_devices(KeyboardInput.DEVICE_ID, InputDevice.NO_DEVICE_ID)
