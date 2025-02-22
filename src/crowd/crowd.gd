class_name Crowd
extends Node3D

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var blocks: Node3D = $Blocks

@export var crowd_after_point_sounds := [
	preload("res://src/crowd/sounds/crowd-after-point1.wav"),
	preload("res://src/crowd/sounds/crowd-after-point2.wav"),
]
@export var crowd_idle_sounds := [
	preload("res://src/crowd/sounds/crowd-idle.wav"),
]


func _ready() -> void:
	play_sound(crowd_idle_sounds[0], true)


func victory():
	play_sound(crowd_after_point_sounds[randi() % crowd_after_point_sounds.size()])
	# Crowd victory animations
	for block in blocks.get_children():
		block.play_victory()


func play_sound(stream: AudioStream, loop := false):
	audio_stream_player.stream = stream
	#if loop:
	#audio_stream_player.stream.loop_mode = AudioStreamWAV.LoopMode.LOOP_FORWARD
	#audio_stream_player.stream.loop_end = -1
	audio_stream_player.play()
	print(stream)
