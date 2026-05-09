class_name MatchReplayController
extends Node

signal recording_started
signal recording_stopped(duration_seconds: float)
signal playback_started(duration_seconds: float)
signal playback_paused(playhead_seconds: float)
signal playback_resumed(playhead_seconds: float)
signal playback_stopped
signal playback_finished
signal replay_loaded(duration_seconds: float)
signal replay_saved(path: String)
signal playback_frame_applied(frame_index: int, playhead_seconds: float)

enum CameraMode {
	BROADCAST,
	FOLLOW_BALL,
	FOLLOW_LAST_HITTER,
}

var enabled: bool = true
var persistence_enabled: bool = true
var save_path: String = "user://last_match_replay.save"
var debug_hotkey_enabled: bool = true
var camera_mode: CameraMode = CameraMode.BROADCAST
var follow_offset: Vector3 = Vector3(0.0, 3.5, 10.0)

var _match_manager: MatchManager
var _player0: Player
var _player1: Player
var _cameras: MatchCameras

var _frames: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _elapsed_seconds: float = 0.0
var _cursor: int = 0
var _playhead_seconds: float = 0.0
var _is_recording: bool = false
var _is_playing: bool = false
var _is_playback_paused: bool = false
var _replay_ball_visual: Ball
var _tree_was_paused_before_playback: bool = false
var _event_cursor: int = 0


func initialize(match_manager: MatchManager, player0: Player, player1: Player, cameras: MatchCameras) -> void:
	_match_manager = match_manager
	_player0 = player0
	_player1 = player1
	_cameras = cameras


func process_recording(delta: float) -> void:
	if _is_recording:
		_record_frame(delta)


func process_playback(delta: float) -> void:
	if _is_playing and not _is_playback_paused:
		_playback_step(delta)


func begin_recording() -> void:
	if not enabled:
		return

	_frames.clear()
	_events.clear()
	_elapsed_seconds = 0.0
	_cursor = 0
	_playhead_seconds = 0.0
	_event_cursor = 0
	_is_recording = true
	_is_playing = false
	_is_playback_paused = false
	record_event("recording_started", {})
	recording_started.emit()


func stop_recording() -> void:
	if not _is_recording:
		return

	_is_recording = false
	record_event("recording_stopped", {})
	if persistence_enabled:
		save_to_disk(save_path)
	recording_stopped.emit(_elapsed_seconds)


func record_event(event_type: String, payload: Dictionary) -> void:
	if not _is_recording:
		return

	_events.append({
		"time": _elapsed_seconds,
		"type": event_type,
		"payload": payload,
	})


func has_replay() -> bool:
	return not _frames.is_empty()


func get_duration_seconds() -> float:
	return _elapsed_seconds


func get_playhead_seconds() -> float:
	return _playhead_seconds


func get_progress() -> float:
	if _elapsed_seconds <= 0.0:
		return 0.0
	return clampf(_playhead_seconds / _elapsed_seconds, 0.0, 1.0)


func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)


func is_playing() -> bool:
	return _is_playing


func is_playback_paused() -> bool:
	return _is_playback_paused


func start_playback() -> void:
	if not enabled:
		push_warning("Replay is disabled")
		return

	if _frames.is_empty():
		push_warning("Replay not available yet: no frames captured")
		return

	if _is_playing:
		return

	stop_recording()
	_is_playing = true
	_is_playback_paused = false
	_cursor = 0
	_playhead_seconds = 0.0
	_event_cursor = 0
	_tree_was_paused_before_playback = _match_manager.get_tree().paused
	_match_manager.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_match_manager.get_tree().paused = true
	_set_live_simulation_enabled(false)
	_ensure_replay_ball_visual()
	_apply_frame(_frames[0])
	_set_replay_animation_paused(false)
	playback_started.emit(_elapsed_seconds)


func stop_playback() -> void:
	if not _is_playing:
		return

	_is_playing = false
	_is_playback_paused = false
	_set_replay_animation_paused(false)
	_set_live_simulation_enabled(true)
	if is_instance_valid(_replay_ball_visual):
		_replay_ball_visual.queue_free()
		_replay_ball_visual = null
	_match_manager.get_tree().paused = _tree_was_paused_before_playback
	_match_manager.process_mode = Node.PROCESS_MODE_INHERIT
	if _player0:
		_player0.reset_replay_visual_state()
	if _player1:
		_player1.reset_replay_visual_state()
	playback_stopped.emit()


func pause_playback() -> void:
	if not _is_playing or _is_playback_paused:
		return
	_is_playback_paused = true
	if not _frames.is_empty():
		_playhead_seconds = _frames[_cursor]["time"]
		_apply_frame(_frames[_cursor])
	_set_replay_animation_paused(true)
	_set_all_live_balls_enabled(false)
	playback_paused.emit(_playhead_seconds)


func resume_playback() -> void:
	if not _is_playing or not _is_playback_paused:
		return
	_is_playback_paused = false
	_set_replay_animation_paused(false)
	_set_all_live_balls_enabled(false)
	playback_resumed.emit(_playhead_seconds)


func toggle_pause_playback() -> void:
	if _is_playback_paused:
		resume_playback()
	else:
		pause_playback()


func rewind_seconds(seconds: float = 2.0) -> void:
	if _frames.is_empty():
		return
	_seek_to_time(_playhead_seconds - maxf(0.0, seconds))


func forward_seconds(seconds: float = 2.0) -> void:
	if _frames.is_empty():
		return
	_seek_to_time(_playhead_seconds + maxf(0.0, seconds))


func step_frame(direction: int) -> void:
	if not _is_playing:
		return

	pause_playback()
	if direction > 0:
		_cursor = mini(_cursor + 1, _frames.size() - 1)
	else:
		_cursor = maxi(_cursor - 1, 0)

	_playhead_seconds = _frames[_cursor]["time"]
	_event_cursor = 0
	_process_events_until_playhead()
	_apply_frame(_frames[_cursor])
	playback_frame_applied.emit(_cursor, _playhead_seconds)


func save_to_disk(path: String = save_path) -> bool:
	if _frames.is_empty():
		return false

	var payload := {
		"version": 1,
		"duration": _elapsed_seconds,
		"frames": _frames,
		"events": _events,
	}

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("MatchReplayController.save_to_disk failed: %s" % error_string(FileAccess.get_open_error()))
		return false

	file.store_string(var_to_str(payload))
	replay_saved.emit(path)
	return true


func load_from_disk(path: String = save_path) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MatchReplayController.load_from_disk failed: %s" % error_string(FileAccess.get_open_error()))
		return false

	var payload: Variant = str_to_var(file.get_as_text())
	if typeof(payload) != TYPE_DICTIONARY:
		push_warning("Replay payload has invalid format")
		return false

	var payload_dict: Dictionary = payload
	if not payload_dict.has("frames"):
		push_warning("Replay payload does not contain frames")
		return false

	_frames = payload_dict.get("frames", [])
	_events = payload_dict.get("events", [])
	_elapsed_seconds = float(payload_dict.get("duration", 0.0))
	_cursor = 0
	_playhead_seconds = 0.0
	_event_cursor = 0
	replay_loaded.emit(_elapsed_seconds)
	return not _frames.is_empty()


func _record_frame(delta: float) -> void:
	if not _player0 or not _player1:
		return

	var ball: Ball = _match_manager.get_active_ball()
	var frame := {
		"time": _elapsed_seconds,
		"player0_transform": _player0.global_transform,
		"player0_velocity": _player0.velocity,
		"player0_state": _player0.get_current_state(),
		"player0_stroke_payload": _serialize_stroke(_player0.queued_stroke),
		"player0_animation_snapshot": _player0.get_replay_animation_snapshot(),
		"player1_transform": _player1.global_transform,
		"player1_velocity": _player1.velocity,
		"player1_state": _player1.get_current_state(),
		"player1_stroke_payload": _serialize_stroke(_player1.queued_stroke),
		"player1_animation_snapshot": _player1.get_replay_animation_snapshot(),
		"last_hitter_index": _match_manager.get_player_index(_match_manager.last_hitter) if _match_manager.last_hitter else -1,
		"ball_exists": false,
	}

	if is_instance_valid(ball):
		frame["ball_exists"] = true
		frame["ball_transform"] = ball.global_transform
		frame["ball_velocity"] = ball.velocity
		frame["ball_spin"] = ball.spin

	_frames.append(frame)
	_elapsed_seconds += delta


func _playback_step(delta: float) -> void:
	if _frames.is_empty():
		stop_playback()
		return

	_playhead_seconds += delta
	_playhead_seconds = minf(_playhead_seconds, _elapsed_seconds)

	while (_cursor + 1) < _frames.size() and _frames[_cursor + 1]["time"] <= _playhead_seconds:
		_cursor += 1

	_process_events_until_playhead()
	_apply_frame(_frames[_cursor])
	playback_frame_applied.emit(_cursor, _playhead_seconds)

	if _cursor >= _frames.size() - 1:
		playback_finished.emit()
		pause_playback()


func _seek_to_time(target_time: float) -> void:
	if _frames.is_empty():
		return

	_playhead_seconds = clampf(target_time, 0.0, _elapsed_seconds)
	_cursor = 0
	while (_cursor + 1) < _frames.size() and _frames[_cursor + 1]["time"] <= _playhead_seconds:
		_cursor += 1

	_event_cursor = 0
	_process_events_until_playhead()
	_apply_frame(_frames[_cursor])
	playback_frame_applied.emit(_cursor, _playhead_seconds)


func _process_events_until_playhead() -> void:
	while _event_cursor < _events.size() and _events[_event_cursor]["time"] <= _playhead_seconds:
		_apply_event(_events[_event_cursor])
		_event_cursor += 1


func _apply_event(event_data: Dictionary) -> void:
	if not event_data.has("type"):
		return

	var event_type: String = event_data["type"]
	var payload: Dictionary = event_data.get("payload", {})
	if event_type != "stroke":
		return

	var player_index: int = int(payload.get("player", -1))
	var stroke_payload: Dictionary = payload.get("stroke", {})
	if stroke_payload.is_empty():
		return

	if player_index == 0 and _player0:
		_player0.play_replay_stroke(stroke_payload)
	elif player_index == 1 and _player1:
		_player1.play_replay_stroke(stroke_payload)


func _apply_frame(frame: Dictionary) -> void:
	if _player0:
		_player0.apply_replay_frame(
			frame["player0_transform"],
			frame["player0_velocity"],
			int(frame["player0_state"]),
			frame.get("player0_stroke_payload", {}),
			frame.get("player0_animation_snapshot", {})
		)
	if _player1:
		_player1.apply_replay_frame(
			frame["player1_transform"],
			frame["player1_velocity"],
			int(frame["player1_state"]),
			frame.get("player1_stroke_payload", {}),
			frame.get("player1_animation_snapshot", {})
		)

	if frame["ball_exists"]:
		_ensure_replay_ball_visual()
		if is_instance_valid(_replay_ball_visual):
			_replay_ball_visual.visible = true
			_replay_ball_visual.global_transform = frame["ball_transform"]
			_replay_ball_visual.velocity = frame["ball_velocity"]
			_replay_ball_visual.spin = frame["ball_spin"]
	elif is_instance_valid(_replay_ball_visual):
		_replay_ball_visual.visible = false

	_update_camera(frame)


func _update_camera(frame: Dictionary) -> void:
	if not _cameras or not _cameras.active_cam:
		return

	match camera_mode:
		CameraMode.BROADCAST:
			return
		CameraMode.FOLLOW_BALL:
			if frame["ball_exists"]:
				var ball_target: Vector3 = frame["ball_transform"].origin
				_cameras.active_cam.global_position = ball_target + follow_offset
				_cameras.active_cam.look_at(ball_target, Vector3.UP)
		CameraMode.FOLLOW_LAST_HITTER:
			var hitter_index: int = frame["last_hitter_index"]
			var target_transform: Transform3D = (
				frame["player0_transform"] if hitter_index == 0 else frame["player1_transform"]
			)
			if hitter_index < 0:
				target_transform = frame["player0_transform"]
			var target_pos: Vector3 = target_transform.origin
			_cameras.active_cam.global_position = target_pos + follow_offset
			_cameras.active_cam.look_at(target_pos, Vector3.UP)


func _ensure_replay_ball_visual() -> void:
	if is_instance_valid(_replay_ball_visual):
		return

	if not GlobalScenes.BALL_SCENE:
		push_error("Replay cannot create ball visual: GlobalScenes.BALL_SCENE missing")
		return

	_replay_ball_visual = GlobalScenes.BALL_SCENE.instantiate()
	_replay_ball_visual.name = "ReplayBall"
	_replay_ball_visual.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_replay_ball_visual.set_process(false)
	_replay_ball_visual.set_physics_process(false)
	_replay_ball_visual.visible = false
	_match_manager.get_parent().add_child(_replay_ball_visual)


func _set_live_simulation_enabled(is_enabled: bool) -> void:
	if _player0:
		_player0.set_replay_mode(not is_enabled)
		_player0.process_mode = Node.PROCESS_MODE_INHERIT if is_enabled else Node.PROCESS_MODE_WHEN_PAUSED
		_player0.set_replay_animation_paused(false)
		_player0.set_process(is_enabled)
		_player0.set_physics_process(is_enabled)

	if _player1:
		_player1.set_replay_mode(not is_enabled)
		_player1.process_mode = Node.PROCESS_MODE_INHERIT if is_enabled else Node.PROCESS_MODE_WHEN_PAUSED
		_player1.set_replay_animation_paused(false)
		_player1.set_process(is_enabled)
		_player1.set_physics_process(is_enabled)

	_set_all_live_balls_enabled(is_enabled)


func _set_all_live_balls_enabled(is_enabled: bool) -> void:
	var scene_root: Node = _match_manager.get_tree().current_scene
	if not scene_root:
		return
	_set_ball_enabled_recursive(scene_root, is_enabled)


func _set_ball_enabled_recursive(node: Node, is_enabled: bool) -> void:
	if node is Ball and node != _replay_ball_visual:
		node.set_process(is_enabled)
		node.set_physics_process(is_enabled)
		node.visible = is_enabled
		if not is_enabled:
			node.velocity = Vector3.ZERO

	for child in node.get_children():
		_set_ball_enabled_recursive(child, is_enabled)


func _set_replay_animation_paused(paused: bool) -> void:
	if _player0:
		_player0.set_replay_animation_paused(paused)
	if _player1:
		_player1.set_replay_animation_paused(paused)


func _serialize_stroke(stroke: Stroke) -> Dictionary:
	if not stroke:
		return {}

	return {
		"stroke_type": stroke.stroke_type,
		"stroke_power": stroke.stroke_power,
		"stroke_target": stroke.stroke_target,
		"stroke_spin": stroke.stroke_spin,
	}
