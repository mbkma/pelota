@tool
class_name GlobalCrowdConfig
extends Resource

## Global configuration for the crowd system
## This resource centralizes global crowd parameters like sounds

## Audio configuration
## Background crowd noise sounds to play during idle
@export var idle_sounds: Array[AudioStream] = []:
	set(new_setting):
		idle_sounds = new_setting
		changed.emit()

## Crowd celebration sounds to play after scoring
@export var after_point_sounds: Array[AudioStream] = []:
	set(new_setting):
		after_point_sounds = new_setting
		changed.emit()


## Get a random idle sound
func get_random_idle_sound() -> AudioStream:
	if idle_sounds.is_empty():
		return null
	return idle_sounds[randi() % idle_sounds.size()]


## Get a random after-point sound
func get_random_after_point_sound() -> AudioStream:
	if after_point_sounds.is_empty():
		return null
	return after_point_sounds[randi() % after_point_sounds.size()]
