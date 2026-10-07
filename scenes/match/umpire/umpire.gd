## Umpire audio system for calling score, faults, and game events
class_name Umpire
extends Node3D

## Calls by key: the point score as "<player0 points>-<player1 points>" (TennisPoint values,
## e.g. "1-2" for 15-30), "advantage" and "out"
@export var umpire_sounds: Dictionary[String, AudioStream]

@onready var _audio_stream_player: AudioStreamPlayer3D = $AudioStreamPlayer


## Announce "fault"
func say_fault() -> void:
	_play(umpire_sounds["out"])


## Announce the point score after a short delay (nothing at the start of a game)
func say_score(score: Score) -> void:
	var points: Array[int] = score.points
	if points[0] == Score.TennisPoint.LOVE and points[1] == Score.TennisPoint.LOVE:
		return

	await get_tree().create_timer(1.0).timeout
	var key: String = "%d-%d" % [points[0], points[1]]
	if points[0] == Score.TennisPoint.AD or points[1] == Score.TennisPoint.AD:
		key = "advantage"
	_play(umpire_sounds[key])


func _play(stream: AudioStream) -> void:
	_audio_stream_player.stream = stream
	_audio_stream_player.play()
