## Umpire audio system for calling score, faults, and game events. The calls are heard as in a
## TV broadcast, from the umpire's microphone (not from the chair's position), and the crowd is
## turned down under them (see the Crowd audio bus). Sitting in the chair, the umpire follows the
## ball with the head; without a ball in play the umpire looks at the court.
class_name Umpire
extends Node3D

## Seconds after a point before the umpire calls the score (shortest, longest)
const SCORE_CALL_DELAY: Vector2 = Vector2(2.0, 4.0)
## Where the umpire looks without a ball in play: the middle of the court
const COURT_LOOK_TARGET: Vector3 = Vector3(0.0, 1.0, 0.0)
## How fast (1/s) the head catches up with the ball
const LOOK_FOLLOW_RATE: float = 12.0

## Calls by key: the point score as "<server's points>-<receiver's points>" (TennisPoint values,
## e.g. "1-2" for 15-30), "advantage" and "out"
@export var umpire_sounds: Dictionary[String, AudioStream]

## Ball the umpire follows, null while none is in play
var _ball: Ball

@onready var _audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
## The neck and head turn toward it (see the LookAtModifier3D nodes of the model)
@onready var _look_target: Node3D = $LookTarget


func _process(delta: float) -> void:
	var target: Vector3 = _ball.global_position if is_instance_valid(_ball) else COURT_LOOK_TARGET
	_look_target.global_position = _look_target.global_position.lerp(
		target, 1.0 - exp(-LOOK_FOLLOW_RATE * delta)
	)


## Makes the umpire follow `ball` with the head; null when no ball is in play.
func follow_ball(ball: Ball) -> void:
	_ball = ball


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
