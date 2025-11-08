class_name PelotaButton
extends Button

@export var button_sounds: Array[AudioStream]


func _on_focus_entered() -> void:
	GlobalMusicPlayer.play_sound(button_sounds[0])


func _on_button_down() -> void:
	GlobalMusicPlayer.play_sound(button_sounds[0])
