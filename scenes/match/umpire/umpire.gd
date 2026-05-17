## Umpire audio system for calling score, faults, and game events
class_name Umpire
extends Node3D

@onready var _audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

## Preloaded sound dictionary for all score announcements and game calls
@export var umpire_sounds: Dictionary[String, AudioStream] 
#= {
	#"0-1": AudioStream,
	#"0-2": AudioStream,
	#"0-3": AudioStream,
	#"1-0": AudioStream,
	#"1-1": AudioStream,
	#"1-2": AudioStream,
	#"1-3": AudioStream,
	#"2-0": AudioStream,
	#"2-1": AudioStream,
	#"2-2": AudioStream,
	#"2-3": AudioStream,
	#"3-0": AudioStream,
	#"3-1": AudioStream,
	#"3-2": AudioStream,
	#"3-3": AudioStream,
	#"advantage": AudioStream,
	#"out": AudioStream,
	#"second_serve": AudioStream,
#}


## Announce "second serve"
func say_second_serve() -> void:
	_audio_stream_player.stream = umpire_sounds["second_serve"]
	_audio_stream_player.play()


## Announce "fault"
func say_fault() -> void:
	_audio_stream_player.stream = umpire_sounds["out"]
	_audio_stream_player.play()


## Announce current score after brief delay
func say_score(score: Score) -> void:
	var points: Array[int] = score.points
	if points[0] == score.TennisPoint.LOVE and points[1] == score.TennisPoint.LOVE:
		return

	# Wait before announcing score
	await get_tree().create_timer(1.0).timeout
	var key: String = str(points[0]) + "-" + str(points[1])
	var stream: AudioStream = umpire_sounds.get(key)

	if points[0] == score.TennisPoint.AD or points[1] == score.TennisPoint.AD:
		stream = umpire_sounds["advantage"]

	if stream:
		_audio_stream_player.stream = stream
		_audio_stream_player.play()
	else:
		push_error("Sound not found for score: ", key)
