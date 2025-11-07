class_name PelotaButton
extends Button

var button_sounds := [preload("res://assets/sounds/UI_SFX_Set/rollover4.wav")]


func _on_focus_entered() -> void:
	GlobalMusicPlayer.play_sound(button_sounds[0])


func _on_button_down() -> void:
	GlobalMusicPlayer.play_sound(button_sounds[0])
