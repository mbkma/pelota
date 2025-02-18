extends Node3D

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

@export var crowd_after_point_sounds := [
	preload("res://src/crowd/sounds/crowd-after-point1.wav"),
	preload("res://src/crowd/sounds/crowd-after-point2.wav"),
]
@export var crowd_idle_sounds := [
	preload("res://src/crowd/sounds/crowd-idle.wav"),
]


func _ready():
	for i in range(50):  # Create 50 people
		var person = preload("res://src/crowd/crowd_lonely.tscn").instantiate()
		add_child(person)
		person.position = Vector3(i * 0.7, 0, 0)
		person.get_node(^"AnimationPlayer").play("sit-idle-loop-1")
		i += 1
	play_sound(crowd_idle_sounds[0], true)


func play_sound(stream: AudioStream, loop := false):
	audio_stream_player.stream = stream
	#if loop:
	#audio_stream_player.stream.loop_mode = AudioStreamWAV.LoopMode.LOOP_FORWARD
	#audio_stream_player.stream.loop_end = -1
	audio_stream_player.play()
	print(stream)
