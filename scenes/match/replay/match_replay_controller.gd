## Records the match from its start to its end: the players and the ball every physics
## frame. The recording plays back with the live simulation paused (R toggles it in debug
## builds). Runs while the tree is paused.
class_name MatchReplayController
extends Node

signal playback_started
signal playback_stopped

## Seconds rewind and forward jump
const SEEK_STEP: float = 2.0

@export var match_manager: MatchManager

var _players: Array[Player] = []

var _frames: Array[Dictionary] = []
var _elapsed_seconds: float = 0.0
var _cursor: int = 0
var _playhead_seconds: float = 0.0
var _is_recording: bool = false
var _is_playing: bool = false
var _is_paused: bool = false
var _replay_ball: Ball
var _tree_was_paused: bool = false


func _ready() -> void:
	_players = [match_manager.player0, match_manager.player1]
	match_manager.match_finished.connect(_stop_recording.unbind(1))
	_is_recording = true


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_pressed() and event.keycode == KEY_R:
		toggle_playback()


func _physics_process(delta: float) -> void:
	if _is_playing:
		if not _is_paused:
			_playback_step(delta)
	elif _is_recording and not get_tree().paused:
		_record_frame(delta)


func _stop_recording() -> void:
	_is_recording = false


func get_duration_seconds() -> float:
	return _elapsed_seconds


func get_playhead_seconds() -> float:
	return _playhead_seconds


func is_playing() -> bool:
	return _is_playing


func is_paused() -> bool:
	return _is_paused


func toggle_playback() -> void:
	if _is_playing:
		stop_playback()
	else:
		start_playback()


func start_playback() -> void:
	if _frames.is_empty() or _is_playing:
		return

	_stop_recording()
	_is_playing = true
	_is_paused = false
	_tree_was_paused = get_tree().paused
	get_tree().paused = true
	_set_live_simulation_enabled(false)
	_replay_ball = _players[0].ball_scene.instantiate()
	_replay_ball.name = "ReplayBall"
	_replay_ball.process_mode = Node.PROCESS_MODE_DISABLED
	_replay_ball.visible = false
	match_manager.get_parent().add_child(_replay_ball)
	_seek_to_time(0.0)
	playback_started.emit()


func stop_playback() -> void:
	if not _is_playing:
		return

	_is_playing = false
	_is_paused = false
	_set_animation_paused(false)
	_set_live_simulation_enabled(true)
	_replay_ball.queue_free()
	get_tree().paused = _tree_was_paused
	playback_stopped.emit()


func toggle_pause() -> void:
	if not _is_playing:
		return
	_is_paused = not _is_paused
	_set_animation_paused(_is_paused)
	if _is_paused:
		_seek_to_time(_frames[_cursor]["time"])


func rewind() -> void:
	_seek_to_time(_playhead_seconds - SEEK_STEP)


func forward() -> void:
	_seek_to_time(_playhead_seconds + SEEK_STEP)


## Pauses and steps one recorded frame forward (direction 1) or back (direction -1).
func step_frame(direction: int) -> void:
	if not _is_playing:
		return
	if not _is_paused:
		toggle_pause()
	_cursor = clampi(_cursor + direction, 0, _frames.size() - 1)
	_playhead_seconds = _frames[_cursor]["time"]
	_apply_frame(_frames[_cursor])


func _record_frame(delta: float) -> void:
	var player_frames: Array[Array] = []
	for player in _players:
		player_frames.append(
			[player.global_transform, player.velocity, player.get_replay_animation_snapshot()]
		)
	var frame := {"time": _elapsed_seconds, "players": player_frames}
	var ball: Ball = match_manager.ball
	if is_instance_valid(ball):
		frame["ball"] = [ball.global_transform, ball.velocity, ball.spin]
	_frames.append(frame)
	_elapsed_seconds += delta


func _playback_step(delta: float) -> void:
	_seek_to_time(_playhead_seconds + delta)
	if _cursor >= _frames.size() - 1:
		toggle_pause()


func _seek_to_time(target_time: float) -> void:
	if not _is_playing:
		return
	_playhead_seconds = clampf(target_time, 0.0, _elapsed_seconds)
	_cursor = 0
	while _cursor + 1 < _frames.size() and _frames[_cursor + 1]["time"] <= _playhead_seconds:
		_cursor += 1
	_apply_frame(_frames[_cursor])


func _apply_frame(frame: Dictionary) -> void:
	for i in _players.size():
		var player_frame: Array = frame["players"][i]
		_players[i].apply_replay_frame(player_frame[0], player_frame[1], player_frame[2])

	_replay_ball.visible = frame.has("ball")
	if frame.has("ball"):
		_replay_ball.global_transform = frame["ball"][0]
		_replay_ball.velocity = frame["ball"][1]
		_replay_ball.spin = frame["ball"][2]


func _set_live_simulation_enabled(enabled: bool) -> void:
	for player in _players:
		player.set_replay_mode(not enabled)
		player.process_mode = (
			Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_WHEN_PAUSED
		)
		player.set_process(enabled)
		player.set_physics_process(enabled)

	for node in match_manager.get_parent().get_children():
		if node is Ball and node != _replay_ball:
			node.set_physics_process(enabled)
			node.visible = enabled


func _set_animation_paused(paused: bool) -> void:
	for player in _players:
		player.set_replay_animation_paused(paused)
