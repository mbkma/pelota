## The chair umpire: calls the score like at the US Open, from the server's side ("Fifteen,
## love"), "Deuce", "Advantage" and "Game", "Game and first set", "Game, set and match" with the
## player's name, the tiebreak and its scores ("Three, one" and the leader's name), and a let;
## the electronic line calling calls a serve or a rally ball out "Fault", with its own voice
## from the sound effects, not the umpire's. The umpire's calls are heard as in a TV broadcast,
## from the umpire's microphone (not from the chair's position), and the crowd is turned down
## under them (see the Crowd audio bus). Sitting in the chair, the
## umpire follows the ball with the head; without a ball in play the umpire looks at the court.
class_name Umpire
extends Node3D

## Seconds after a point before the umpire calls the score (shortest, longest)
const SCORE_CALL_DELAY: Vector2 = Vector2(3.0, 5.0)
## Where the umpire looks without a ball in play: the middle of the court
const COURT_LOOK_TARGET: Vector3 = Vector3(0.0, 1.0, 0.0)
## How fast (1/s) the head catches up with the ball
const LOOK_FOLLOW_RATE: float = 12.0
## Bones turned toward the look target, and how much of the turn each takes: the neck some, the
## head the rest
const LOOK_BONES: Dictionary[StringName, float] = {&"Neck": 0.4, &"Head": 1.0}
## How far (rad) the head turns sideways, and up or down
const LOOK_LIMIT_SIDEWAYS: float = deg_to_rad(120.0)
const LOOK_LIMIT_UP_DOWN: float = deg_to_rad(60.0)

@export var calls: UmpireCalls

## The players, by index in the score
var _players: Array[PlayerData] = []
## Games played and sets completed when the umpire last called the score
var _games_played: int = 0
var _sets_completed: int = 0
## Number of calls started; a call (with its name) stops when a newer one starts
var _call_count: int = 0
## Ball the umpire follows, null while none is in play
var _ball: Ball

@onready var _audio_stream_player: AudioStreamPlayer = $UmpirePlayer
## Plays the electronic line calls
@onready var _line_call_player: AudioStreamPlayer = $LineCallPlayer
## The neck and head turn toward it (see _add_look_modifiers)
@onready var _look_target: Node3D = $LookTarget


func _ready() -> void:
	_add_look_modifiers()


## Turns the neck and head toward the look target. Made here rather than in the scene: nodes added
## under the skeleton of the imported model are left out of an exported game.
func _add_look_modifiers() -> void:
	var skeleton: Skeleton3D = $Model/GeneralSkeleton
	for bone in LOOK_BONES:
		var look := LookAtModifier3D.new()
		look.name = "%sLook" % bone
		look.bone_name = bone
		look.influence = LOOK_BONES[bone]
		look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
		look.use_angle_limitation = true
		look.symmetry_limitation = true
		look.primary_limit_angle = LOOK_LIMIT_SIDEWAYS
		look.secondary_limit_angle = LOOK_LIMIT_UP_DOWN
		skeleton.add_child(look)
		look.target_node = look.get_path_to(_look_target)


func _process(delta: float) -> void:
	var target: Vector3 = _ball.global_position if is_instance_valid(_ball) else COURT_LOOK_TARGET
	_look_target.global_position = _look_target.global_position.lerp(
		target, 1.0 - exp(-LOOK_FOLLOW_RATE * delta)
	)


## Makes the umpire follow `ball` with the head; null when no ball is in play.
func follow_ball(ball: Ball) -> void:
	_ball = ball


## The players whose names the umpire calls, by index in the score.
func set_players(players: Array[PlayerData]) -> void:
	_players = players


## A serve or a rally ball landing out: "Fault".
func call_fault() -> void:
	_line_call_player.stream = calls.fault
	_line_call_player.play()


## A serve touching the net cord and landing in: "Let".
func call_let() -> void:
	_say([calls.let])


## Calls the score after a point `winner` won, after a random delay, letting a call still going
## (e.g. "Fault") finish first.
func call_point(score: Score, winner: int) -> void:
	var clips: Array[AudioStream] = _point_call(score, winner)
	_games_played = score.games_played
	_sets_completed = score.completed_sets.size()
	if clips.is_empty():
		return
	await get_tree().create_timer(randf_range(SCORE_CALL_DELAY.x, SCORE_CALL_DELAY.y)).timeout
	if _line_call_player.playing:
		await _line_call_player.finished
	if _audio_stream_player.playing:
		await _audio_stream_player.finished
	_say(clips)


## What the umpire says after a point `winner` won, `score` the score now.
func _point_call(score: Score, winner: int) -> Array[AudioStream]:
	var game_call: Array[AudioStream] = _game_call(score, winner)
	if not game_call.is_empty():
		return game_call
	if score.is_tiebreak:
		return _tiebreak_call(score)
	return _game_score_call(score)


## The call when the point ended a game, a set or the match (the winner's name with it, and
## the tiebreak when it begins); empty otherwise.
func _game_call(score: Score, winner: int) -> Array[AudioStream]:
	var winner_name: AudioStream = _players[winner].name_call
	if score.is_match_over():
		return [calls.game_set_and_match, winner_name]
	if score.completed_sets.size() > _sets_completed:
		return [calls.game_and_set[score.completed_sets.size() - 1], winner_name]
	if score.games_played > _games_played:
		if score.is_tiebreak:
			return [calls.game, winner_name, calls.tiebreak]
		return [calls.game, winner_name]
	return []


## The score within a game, from the server's side: the points ("Fifteen, love"), "Deuce", or
## "Advantage" and the leader's name.
func _game_score_call(score: Score) -> Array[AudioStream]:
	var server: int = score.current_server
	var server_points: int = score.points[server]
	var receiver_points: int = score.points[1 - server]
	if server_points == Score.TennisPoint.AD or receiver_points == Score.TennisPoint.AD:
		var leader: int = server if server_points == Score.TennisPoint.AD else 1 - server
		return [calls.advantage, _players[leader].name_call]
	if server_points == Score.TennisPoint.FORTY and receiver_points == Score.TennisPoint.FORTY:
		return [calls.deuce]
	return [calls.scores["%d-%d" % [server_points, receiver_points]]]


## A tiebreak score: the leader's points first and the leader's name ("Three, one, Sinner"), or
## a tie ("Two all"). Scores beyond the calls' (twenty) are not called.
func _tiebreak_call(score: Score) -> Array[AudioStream]:
	var points: Array[int] = score.tiebreak_points
	var leader: int = 0 if points[0] >= points[1] else 1
	var key: String = "%d-%d" % [points[leader], points[1 - leader]]
	if not calls.tiebreak_scores.has(key):
		return []
	if points[0] == points[1]:
		return [calls.tiebreak_scores[key]]
	return [calls.tiebreak_scores[key], _players[leader].name_call]


## Says `clips` one after the other; a newer call stops it.
func _say(clips: Array[AudioStream]) -> void:
	_call_count += 1
	var count: int = _call_count
	for stream in clips:
		_audio_stream_player.stream = stream
		_audio_stream_player.play()
		await _audio_stream_player.finished
		if count != _call_count:
			return
