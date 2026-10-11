## Umpire audio system for calling score, faults, and game events. The calls are heard as in a
## TV broadcast, from the umpire's microphone (not from the chair's position), and the crowd is
## turned down under them (see the Crowd audio bus).
class_name Umpire
extends Node3D

## Seconds after a point before the umpire calls the score (shortest, longest)
const SCORE_CALL_DELAY: Vector2 = Vector2(2.0, 4.0)

## Calls by key: the point score as "<server's points>-<receiver's points>" (TennisPoint values,
## e.g. "1-2" for 15-30), "advantage" and "out"
@export var umpire_sounds: Dictionary[String, AudioStream]

@onready var _audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


## Announce "fault"
func say_fault() -> void:
	_play(umpire_sounds["out"])


## Announces the point score from the server's side ("15-30": the server has 15) after a random
## delay; nothing at the start of a game.
func say_score(score: Score) -> void:
	var server: int = score.current_server
	var points: Array[int] = [score.points[server], score.points[1 - server]]
	if points[0] == Score.TennisPoint.LOVE and points[1] == Score.TennisPoint.LOVE:
		return

	await get_tree().create_timer(randf_range(SCORE_CALL_DELAY.x, SCORE_CALL_DELAY.y)).timeout
	# Let a call still going (e.g. "out") finish instead of cutting it off
	if _audio_stream_player.playing:
		await _audio_stream_player.finished
	var key: String = "%d-%d" % [points[0], points[1]]
	if points[0] == Score.TennisPoint.AD or points[1] == Score.TennisPoint.AD:
		key = "advantage"
	_play(umpire_sounds[key])


func _play(stream: AudioStream) -> void:
	_audio_stream_player.stream = stream
	_audio_stream_player.play()
