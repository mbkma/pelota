class_name Crowd
extends Node

## Signal emitted when crowd reaction starts
signal crowd_reaction_started(reaction_type: String)

## Signal emitted when crowd reaction ends
signal crowd_reaction_ended(reaction_type: String)

## Reference to the audio stream player
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

## Container for all crowd blocks
@onready var blocks: Node3D = $Blocks

## Track current reaction state
var _current_reaction: String = ""
var config = null

func _ready() -> void:
	if not config:
		return
	_initialize_audio()


## Play idle crowd sound with looping enabled
func play_idle_sound() -> void:
	var sound = config.get_random_idle_sound()
	if sound:
		play_sound(sound, true)


## Trigger a crowd victory reaction
func play_victory() -> void:
	if _current_reaction == "victory":
		push_warning("Crowd: Victory reaction already playing")
		return

	_current_reaction = "victory"
	crowd_reaction_started.emit("victory")

	# Play audio
	var sound = config.get_random_after_point_sound()
	if sound:
		play_sound(sound, false)

	# Play animations in all blocks
	for block in blocks.get_children():
		if block and block.has_method("play_victory"):
			block.play_victory()

	# Get animation duration and schedule end signal
	if audio_stream_player.stream:
		var duration = audio_stream_player.stream.get_length()
		await get_tree().create_timer(duration).timeout
		_on_reaction_finished()


## Play a sound through the audio stream player
func play_sound(stream: AudioStream, loop := false) -> void:
	if not stream:
		push_error("Crowd: Attempted to play null audio stream")
		return

	audio_stream_player.stream = stream
	# TODO: Implement looping when Godot AudioStreamWAV loop support is available
	# if loop:
	#	 audio_stream_player.stream.loop_mode = AudioStreamWAV.LoopMode.LOOP_FORWARD
	#	 audio_stream_player.stream.loop_end = -1
	audio_stream_player.play()


## Cleanup all resources
func cleanup() -> void:
	for block in blocks.get_children():
		if block and block.has_method("cleanup"):
			block.cleanup()

	if audio_stream_player:
		audio_stream_player.stop()


# Private methods

func _initialize_audio() -> void:
	if not audio_stream_player:
		push_error("Crowd: AudioStreamPlayer not found")
		return


func _on_reaction_finished() -> void:
	if _current_reaction != "":
		crowd_reaction_ended.emit(_current_reaction)
		_current_reaction = ""
