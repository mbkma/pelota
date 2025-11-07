## Umpire audio system for calling score, faults, and game events
class_name Umpire
extends Node3D

@onready var _audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

## Preloaded sound dictionary for all score announcements and game calls
@export var umpire_sounds: Dictionary[String, AudioStream] = {
	"0-1": preload("res://src/match/umpire/sounds/0-15.ogg"),
	"0-2": preload("res://src/match/umpire/sounds/0-30.ogg"),
	"0-3": preload("res://src/match/umpire/sounds/0-40.ogg"),
	"1-0": preload("res://src/match/umpire/sounds/15-0.ogg"),
	"1-1": preload("res://src/match/umpire/sounds/15-15.ogg"),
	"1-2": preload("res://src/match/umpire/sounds/15-30.ogg"),
	"1-3": preload("res://src/match/umpire/sounds/15-40.ogg"),
	"2-0": preload("res://src/match/umpire/sounds/30-0.ogg"),
	"2-1": preload("res://src/match/umpire/sounds/30-15.ogg"),
	"2-2": preload("res://src/match/umpire/sounds/30-30.ogg"),
	"2-3": preload("res://src/match/umpire/sounds/30-40.ogg"),
	"3-0": preload("res://src/match/umpire/sounds/40-0.ogg"),
	"3-1": preload("res://src/match/umpire/sounds/40-15.ogg"),
	"3-2": preload("res://src/match/umpire/sounds/40-30.ogg"),
	"3-3": preload("res://src/match/umpire/sounds/40-40.ogg"),
	"advantage": preload("res://src/match/umpire/sounds/advantage.ogg"),
	"out": preload("res://src/match/umpire/sounds/out.wav"),
	"second_serve": preload("res://src/match/umpire/sounds/second_serve.ogg"),
}


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
