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

		# Pick a random idle animation
		var animation_name = person.idle_animations[randi() % person.idle_animations.size()]

		# Play the animation with blending
		var blend_time = 0.5  # Adjust for smoother transitions
		person.animation_player.play(animation_name, blend_time)

		# Offset animation randomly
		var animation_length = person.animation_player.get_animation(animation_name).length
		person.animation_player.seek(randf_range(0, animation_length), true)

		# Loop through animations smoothly
		person.animation_player.animation_finished.connect(
			func _on_animation_finished(anim_name):
				var new_animation = person.idle_animations[randi() % person.idle_animations.size()]
				print(blend_time)
				person.animation_player.play(new_animation, blend_time)
		)

	play_sound(crowd_idle_sounds[0], true)


func play_sound(stream: AudioStream, loop := false):
	audio_stream_player.stream = stream
	#if loop:
	#audio_stream_player.stream.loop_mode = AudioStreamWAV.LoopMode.LOOP_FORWARD
	#audio_stream_player.stream.loop_end = -1
	audio_stream_player.play()
	print(stream)
