class_name Crowd
extends Node

## Signal emitted when crowd reaction starts
signal crowd_reaction_started(reaction_type: String)

## Signal emitted when crowd reaction ends
signal crowd_reaction_ended(reaction_type: String)

@export var config: CrowdAudioConfig

## Container for all crowd blocks
@export var blocks: Array[Node3D]

## Track current reaction state
var _current_reaction: String = ""

## Reference to the audio stream player
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	audio_stream_player.finished.connect(_on_audio_finished)
	play_idle_sound()


## Play an idle crowd sound; another one follows when it ends and no reaction is playing
func play_idle_sound() -> void:
	var sound = config.get_random_idle_sound()
	if sound:
		play_sound(sound)


## Trigger a crowd victory reaction
func play_victory() -> void:
	if _current_reaction == "victory":
		# Still cheering from the previous point.
		return

	_current_reaction = "victory"
	crowd_reaction_started.emit("victory")

	# Play audio
	var sound = config.get_random_after_point_sound()
	if sound:
		play_sound(sound)

	# Play animations in all blocks
	for block in blocks:
		for crowd_block in block.get_children():
			if crowd_block and crowd_block.has_method("play_victory"):
				crowd_block.play_victory()


## Play a sound through the audio stream player
func play_sound(stream: AudioStream) -> void:
	if not stream:
		push_error("Crowd: Attempted to play null audio stream")
		return

	audio_stream_player.stream = stream

	audio_stream_player.play()


## Cleanup all resources
func cleanup() -> void:
	for block in blocks:
		for crowd_block in block.get_children():
			if crowd_block and crowd_block.has_method("cleanup"):
				crowd_block.cleanup()

	if audio_stream_player:
		audio_stream_player.stop()


# Private methods


## A reaction ends with its sound; the idle ambience continues afterwards.
func _on_audio_finished() -> void:
	if _current_reaction != "":
		crowd_reaction_ended.emit(_current_reaction)
		_current_reaction = ""
	play_idle_sound()
