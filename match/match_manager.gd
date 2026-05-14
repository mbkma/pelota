## Manages match state, scoring, and game flow for tennis matches
class_name MatchManager
extends Node

## Emitted when players have been positioned
signal players_placed

## Emitted whenever the match active ball reference changes
signal active_ball_changed(ball: Ball)
## Emitted when replay recording starts
signal replay_recording_started
## Emitted when replay recording stops
signal replay_recording_stopped(duration_seconds: float)
## Emitted when replay playback starts
signal replay_started(duration_seconds: float)
## Emitted when replay playback reaches the final frame
signal replay_finished
## Emitted when replay playback is stopped manually
signal replay_stopped
## Emitted when replay playback is paused
signal replay_paused(playhead_seconds: float)
## Emitted when replay playback is resumed
signal replay_resumed(playhead_seconds: float)

enum MatchState { NOT_STARTED, IDLE, SERVE, SECOND_SERVE, PLAY, FAULT, GAME_OVER }
enum ReplayCameraMode {
	BROADCAST,
	FOLLOW_BALL,
	FOLLOW_LAST_HITTER,
}

## Reference to the last player who hit the ball
var last_hitter: Player

## History of all match state changes
var state_history: Array[MatchState] = []

## Current match state (use setter to trigger state_changed signal)
var current_state: MatchState = MatchState.NOT_STARTED:
	set(value):
		if value != current_state:
			state_history.append(value)
			current_state = value
			_log_state_change(value)

## Valid service zone for current serve
var _valid_serve_zone: Court.CourtRegion

## Valid rally zone for current rally
var _valid_rally_zone: Court.CourtRegion

## Number of ground contacts in current rally
var _ground_contacts: int = 0

var _replay_controller: MatchReplayController

@onready var match_data: MatchData

@export var player0: Player
@export var player1: Player
@export var ball: Ball
@export var court: Court
@export var stadium: Stadium
@export var television_hud: TelevisionHud
@export var umpire: Umpire
@export var crowd: Crowd
@export var cameras: MatchCameras
## Enables match replay capture/playback for this manager.
@export var replay_enabled: bool = true
## Enables debug replay toggle key (R in debug builds).
@export var replay_debug_hotkey_enabled: bool = true
## Replay camera behavior during playback.
@export var replay_camera_mode: ReplayCameraMode = ReplayCameraMode.BROADCAST
## Follow-camera offset when replay camera mode tracks ball/player.
@export var replay_follow_offset: Vector3 = Vector3(0.0, 3.5, 10.0)
## Automatically save replay to disk after recording stops.
@export var replay_persistence_enabled: bool = true
## Save path for persisted replay payload.
@export var replay_save_path: String = "user://last_match_replay.save"


func _update_valid_serve_zone_from_server_position() -> void:
	_valid_serve_zone = (
		Court.CourtRegion.BACK_SINGLES_BOX
		if get_server().position.z > 0
		else Court.CourtRegion.FRONT_SINGLES_BOX
	)


func _is_debug_add_point_event(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed):
		return false
	return event.keycode == KEY_T


func _is_debug_replay_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed):
		return false
	return event.keycode == KEY_R

func _ready() -> void:
	if not player0 or not player1 or not court or not stadium or not television_hud:
		push_error("MatchManager not properly initialized! Missing required nodes.")
		return

	# Set up logger name
	set_meta("logger_name", "MatchManager")

	# Reset input assignments for new match (important for gamepad assignment)
	HumanController.reset_input_assignments()

	# Set opponent references for each player
	player0.opponent = player1
	player1.opponent = player0

	match_data = MatchData.new(player0.player_data, player1.player_data)
	player0.ball_hit.connect(_on_player0_ball_hit)
	player1.ball_hit.connect(_on_player1_ball_hit)
	player0.ball_spawned.connect(_on_player_ball_spawned)
	player1.ball_spawned.connect(_on_player_ball_spawned)
	player0.active_ball_changed.connect(_on_player_active_ball_changed)
	player1.active_ball_changed.connect(_on_player_active_ball_changed)
	if not active_ball_changed.is_connected(player0.set_active_ball):
		active_ball_changed.connect(player0.set_active_ball)
	if not active_ball_changed.is_connected(player1.set_active_ball):
		active_ball_changed.connect(player1.set_active_ball)
	_connect_player_lifecycle(player0)
	_connect_player_lifecycle(player1)
	television_hud.score_display.player_1_score_panel.set_player(player0.player_data)
	television_hud.score_display.player_2_score_panel.set_player(player1.player_data)
	
	cameras.register_camera(player0.first_person_camera)
	cameras.register_camera(player1.first_person_camera)
	cameras.player0 = player0
	cameras.player1 = player1
	_setup_replay_controller()
	place_players()
	if crowd:
		crowd.play_idle_sound()
	_begin_replay_recording()
	start_match()


## Handle debug input (T key to add point for testing)
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if _is_debug_add_point_event(event):
		add_point(randi() % 2)
	if replay_debug_hotkey_enabled and _is_debug_replay_toggle_event(event):
		if is_replay_playing():
			stop_replay()
		else:
			start_replay()


func _physics_process(delta: float) -> void:
	if not _replay_controller:
		return
	_replay_controller.process_recording(delta)
	_replay_controller.process_playback(delta)


## Set active ball and connect its signals
func set_active_ball(b: Ball) -> void:
	if is_instance_valid(ball) and ball != b:
		_clear_ball()

	ball = b
	active_ball_changed.emit(ball)
	if not ball:
		return

	if not ball.on_ground.is_connected(_on_ball_on_ground):
		ball.on_ground.connect(_on_ball_on_ground)
	if not ball.on_net.is_connected(_on_ball_on_net):
		ball.on_net.connect(_on_ball_on_net)


func get_active_ball() -> Ball:
	return ball


func _setup_replay_controller() -> void:
	_replay_controller = MatchReplayController.new()
	_replay_controller.name = "MatchReplayController"
	add_child(_replay_controller)
	_replay_controller.initialize(self, player0, player1, cameras)
	_replay_controller.enabled = replay_enabled
	_replay_controller.persistence_enabled = replay_persistence_enabled
	_replay_controller.save_path = replay_save_path
	_replay_controller.debug_hotkey_enabled = replay_debug_hotkey_enabled
	_replay_controller.camera_mode = int(replay_camera_mode) as MatchReplayController.CameraMode
	_replay_controller.follow_offset = replay_follow_offset

	_replay_controller.recording_started.connect(_on_replay_recording_started)
	_replay_controller.recording_stopped.connect(_on_replay_recording_stopped)
	_replay_controller.playback_started.connect(_on_replay_playback_started)
	_replay_controller.playback_paused.connect(_on_replay_playback_paused)
	_replay_controller.playback_resumed.connect(_on_replay_playback_resumed)
	_replay_controller.playback_finished.connect(_on_replay_playback_finished)
	_replay_controller.playback_stopped.connect(_on_replay_playback_stopped)


func _on_replay_recording_started() -> void:
	replay_recording_started.emit()


func _on_replay_recording_stopped(duration_seconds: float) -> void:
	replay_recording_stopped.emit(duration_seconds)


func _on_replay_playback_started(duration_seconds: float) -> void:
	replay_started.emit(duration_seconds)


func _on_replay_playback_paused(playhead_seconds: float) -> void:
	replay_paused.emit(playhead_seconds)


func _on_replay_playback_resumed(playhead_seconds: float) -> void:
	replay_resumed.emit(playhead_seconds)


func _on_replay_playback_finished() -> void:
	replay_finished.emit()


func _on_replay_playback_stopped() -> void:
	replay_stopped.emit()


func _connect_player_lifecycle(player: Player) -> void:
	var bus: MatchLifecycleBus = player.get_lifecycle_bus()
	if not bus:
		push_error("MatchManager: Player lifecycle bus missing for %s" % player.name)
		return

	if not bus.serve_requested.is_connected(_on_player_lifecycle_serve_requested):
		bus.serve_requested.connect(_on_player_lifecycle_serve_requested)
	if not bus.serve_completed.is_connected(_on_player_lifecycle_serve_completed):
		bus.serve_completed.connect(_on_player_lifecycle_serve_completed)
	if not bus.point_ended.is_connected(_on_player_lifecycle_point_ended):
		bus.point_ended.connect(_on_player_lifecycle_point_ended)


func _on_ball_on_net() -> void:
	pass

## Get the opponent of the given player
func get_opponent(player: Player) -> Player:
	if player == player0:
		return player1
	return player0


## Get the index (0 or 1) of the given player
func get_player_index(player: Player) -> int:
	if player == player0:
		return 0
	return 1


func get_valid_serve_zone() -> Court.CourtRegion:
	return _valid_serve_zone


func get_valid_rally_zone() -> Court.CourtRegion:
	return _valid_rally_zone


func get_ground_contacts() -> int:
	return _ground_contacts


func get_server_index() -> int:
	return match_data.match_score.current_server


func get_server_name() -> String:
	var server_player: Player = get_server()
	if server_player and server_player.player_data:
		return server_player.player_data.last_name
	return "Unknown"


func get_rally_length() -> int:
	return match_data.rally_length


func get_last_hitter_name() -> String:
	if last_hitter and last_hitter.player_data:
		return last_hitter.player_data.last_name
	return "None"


## Request the current server to serve
func set_player_serve() -> void:
	_stop_players()
	_clear_ball()
	place_players()
	await players_placed
	if match_data.get_server() == 0:
		player0.request_serve()
	else:
		player1.request_serve()


## Start a new match
func start_match() -> void:
	_update_valid_serve_zone_from_server_position()
	_valid_rally_zone = _valid_serve_zone
	current_state = MatchState.SERVE
	_record_replay_event("match_started", {"state": current_state})
	set_player_serve()


## End the match
func end_match(_winner: String) -> void:
	current_state = MatchState.GAME_OVER
	_record_replay_event("match_ended", {"state": current_state})
	_stop_replay_recording()


## Reset match to starting state
func reset_match() -> void:
	stop_replay()
	_begin_replay_recording()
	current_state = MatchState.NOT_STARTED


## Swap rally zone from back to front or vice versa
func _swap_valid_rally_zone() -> void:
	_valid_rally_zone = (
		Court.CourtRegion.BACK_SINGLES_BOX
		if _valid_rally_zone == Court.CourtRegion.FRONT_SINGLES_BOX
		else Court.CourtRegion.FRONT_SINGLES_BOX
	)


## Handle ball landing on ground (serve, rally, or fault detection)
func _on_ball_on_ground() -> void:
	if current_state == MatchState.IDLE:
		return
	if current_state == MatchState.SERVE:
		_process_serve_ground_contact()
	elif current_state == MatchState.SECOND_SERVE:
		_process_second_serve_ground_contact()
	elif current_state == MatchState.PLAY:
		_process_rally_ground_contact()

	if current_state == MatchState.FAULT:
		_handle_fault()


## Process ground contact during first serve
func _process_serve_ground_contact() -> void:
	var valid_box: Court.CourtRegion = get_valid_service_box()
	if court.is_ball_in_court_region(ball.position, valid_box):
		current_state = MatchState.PLAY
		_ground_contacts += 1
		_swap_valid_rally_zone()
	else:
		current_state = MatchState.SECOND_SERVE
		_clear_ball()
		if umpire:
			umpire.say_second_serve()
		set_player_serve()


## Process ground contact during second serve
func _process_second_serve_ground_contact() -> void:
	var valid_box: Court.CourtRegion = get_valid_service_box()
	if court.is_ball_in_court_region(ball.position, valid_box):
		current_state = MatchState.PLAY
		_ground_contacts += 1
		_swap_valid_rally_zone()
	else:
		current_state = MatchState.FAULT


## Process ground contact during rally play
func _process_rally_ground_contact() -> void:
	if court.is_ball_in_court_region(ball.position, _valid_rally_zone):
		_ground_contacts += 1
		if _ground_contacts < GameConstants.GROUND_CONTACT_THRESHOLD:
			_swap_valid_rally_zone()
		else:
			current_state = MatchState.FAULT
	else:
		current_state = MatchState.FAULT


## Handle fault condition (out of bounds or double fault)
func _handle_fault() -> void:
	_stop_players()
	_clear_ball()
	if umpire:
		if _ground_contacts == 0:
			umpire.say_fault()
	if crowd:
		crowd.play_victory()

	var point_winner: Player
	if _ground_contacts == 0:
		point_winner = get_opponent(last_hitter)
	else:
		point_winner = last_hitter

	current_state = MatchState.IDLE
	_valid_rally_zone = _valid_serve_zone
	_ground_contacts = 0
	add_point(get_player_index(point_winner))


## Stop both players' movement and actions
func _stop_players() -> void:
	player0.stop()
	player1.stop()


## Add a point to the winner and handle score update
func add_point(winner: int) -> void:
	_record_replay_event("point_awarded", {"winner": winner})
	match_data.add_point(winner)
	television_hud.update_score(match_data.get_score())
	if umpire:
		umpire.say_score(match_data.get_score())
	await (
		get_tree()
		. create_timer(GameConstants.FAULT_DELAY + GameConstants.POINT_RESET_EXTRA_DELAY)
		. timeout
	)
	place_players()
	await players_placed
	_update_valid_serve_zone_from_server_position()
	current_state = MatchState.SERVE
	set_player_serve()


## Get the current server player
func get_server() -> Player:
	var server_index: int = match_data.match_score.current_server
	if server_index == 0:
		return player0
	return player1


## Clear ball signals
func _clear_ball() -> void:
	if is_instance_valid(ball):
		if ball.on_ground.is_connected(_on_ball_on_ground):
			ball.on_ground.disconnect(_on_ball_on_ground)
		if ball.on_net.is_connected(_on_ball_on_net):
			ball.on_net.disconnect(_on_ball_on_net)


## Check if server serves from deuce side (even total points)
func is_serve_from_deuce_side() -> bool:
	var score = match_data.get_score()
	var total_points: int = score.points[0] + score.points[1]
	return (total_points % 2) == 0


## Get the valid service box for current serve
func get_valid_service_box() -> Court.CourtRegion:
	var serve_from_deuce_side: bool = is_serve_from_deuce_side()

	var valid_service_box: Court.CourtRegion
	if _valid_serve_zone == Court.CourtRegion.BACK_SINGLES_BOX:
		valid_service_box = (
			Court.CourtRegion.LEFT_BACK_SERVICE_BOX
			if serve_from_deuce_side
			else Court.CourtRegion.RIGHT_BACK_SERVICE_BOX
		)
	else:
		valid_service_box = (
			Court.CourtRegion.RIGHT_FRONT_SERVICE_BOX
			if serve_from_deuce_side
			else Court.CourtRegion.LEFT_FRONT_SERVICE_BOX
		)

	return valid_service_box


## Position players based on current server and game state
func place_players() -> void:
	var server_index: int = match_data.get_server()
	var score = match_data.get_score()
	var total_games: int = score.games[0] + score.games[1]
	var switch_sides: bool = (
		(total_games % GameConstants.SIDE_SWITCH_GAME_CYCLE) == 1
		or (total_games % GameConstants.SIDE_SWITCH_GAME_CYCLE) == 2
	)
	var serve_from_deuce_side: bool = is_serve_from_deuce_side()

	# Determine player positions
	var player0_position: Stadium.StadiumPosition = _get_player_position(
		server_index == 0, serve_from_deuce_side, switch_sides, true
	)
	var player1_position: Stadium.StadiumPosition = _get_player_position(
		server_index == 1, serve_from_deuce_side, switch_sides, false
	)

	# Assign positions to players using stadium positions dictionary
	player0.global_position = stadium.positions[player0_position]
	# Wait one frame to avoid collisions
	await get_tree().physics_frame
	player1.global_position = stadium.positions[player1_position]
	player0.rotation.y = PI if player0.position.z < 0 else 0.0
	player1.rotation.y = PI if player1.position.z < 0 else 0.0
	players_placed.emit()
	cameras.set_camera_for_player(player0)
	cameras.set_camera_for_player(player1)

## Get position for a player based on serve and side information
func _get_player_position(
	is_server: bool, serve_from_deuce_side: bool, switch_sides: bool, _is_player0: bool
) -> Stadium.StadiumPosition:
	if is_server:
		if switch_sides:
			# Server is on back side
			return (
				stadium.StadiumPosition.SERVE_BACK_LEFT
				if serve_from_deuce_side
				else stadium.StadiumPosition.SERVE_BACK_RIGHT
			)
		# Server is on front side
		return (
			stadium.StadiumPosition.SERVE_FRONT_RIGHT
			if serve_from_deuce_side
			else stadium.StadiumPosition.SERVE_FRONT_LEFT
		)
	# Receiver
	if switch_sides:
		return (
			stadium.StadiumPosition.RECEIVE_FRONT_RIGHT
			if serve_from_deuce_side
			else stadium.StadiumPosition.RECEIVE_FRONT_LEFT
		)
	return (
		stadium.StadiumPosition.RECEIVE_BACK_LEFT
		if serve_from_deuce_side
		else stadium.StadiumPosition.RECEIVE_BACK_RIGHT
	)


## Signal Callbacks
####################


func _on_player_ball_spawned(b: Ball) -> void:
	_record_replay_event("ball_spawned", {"player": get_player_index(last_hitter) if last_hitter else -1})
	if is_instance_valid(ball) and ball != b:
		_clear_ball()
		ball.queue_free()
	set_active_ball(b)


func _on_player_active_ball_changed(b: Ball) -> void:
	if b != ball:
		set_active_ball(b)

func _on_player_lifecycle_serve_requested(serving_player: Player) -> void:
	if serving_player == get_server() and stadium:
		stadium.start_serve_clocks()


func _on_player_lifecycle_serve_completed(serving_player: Player) -> void:
	if serving_player == get_server() and stadium:
		if ball:
			stadium.show_serve_speed(ball)
		stadium.stop_serve_clocks()


func _on_player_lifecycle_point_ended(_player: Player) -> void:
	if stadium:
		stadium.stop_serve_clocks()


## Called when player 0 hits the ball
func _on_player0_ball_hit() -> void:
	var stroke_payload := {}
	if player0.queued_stroke:
		stroke_payload = {
			"stroke_type": player0.queued_stroke.stroke_type,
			"stroke_power": player0.queued_stroke.stroke_power,
			"stroke_target": player0.queued_stroke.stroke_target,
			"stroke_spin": player0.queued_stroke.stroke_spin,
		}
	_record_replay_event("stroke", {"player": 0, "stroke": stroke_payload})
	if current_state == MatchState.PLAY:
		if _ground_contacts == 0:
			_swap_valid_rally_zone()
		_ground_contacts = 0
	last_hitter = player0


## Called when player 1 hits the ball
func _on_player1_ball_hit() -> void:
	var stroke_payload := {}
	if player1.queued_stroke:
		stroke_payload = {
			"stroke_type": player1.queued_stroke.stroke_type,
			"stroke_power": player1.queued_stroke.stroke_power,
			"stroke_target": player1.queued_stroke.stroke_target,
			"stroke_spin": player1.queued_stroke.stroke_spin,
		}
	_record_replay_event("stroke", {"player": 1, "stroke": stroke_payload})
	if current_state == MatchState.PLAY:
		if _ground_contacts == 0:
			_swap_valid_rally_zone()
		_ground_contacts = 0
	last_hitter = player1


func _begin_replay_recording() -> void:
	if not _replay_controller:
		return
	_replay_controller.enabled = replay_enabled
	_replay_controller.persistence_enabled = replay_persistence_enabled
	_replay_controller.save_path = replay_save_path
	_replay_controller.camera_mode = int(replay_camera_mode) as MatchReplayController.CameraMode
	_replay_controller.follow_offset = replay_follow_offset
	_replay_controller.begin_recording()


func _stop_replay_recording() -> void:
	if not _replay_controller:
		return
	_replay_controller.stop_recording()


func _record_replay_frame(delta: float) -> void:
	if _replay_controller:
		_replay_controller.process_recording(delta)


func _record_replay_event(event_type: String, payload: Dictionary) -> void:
	if _replay_controller:
		_replay_controller.record_event(event_type, payload)


func has_replay() -> bool:
	return _replay_controller and _replay_controller.has_replay()


func get_replay_duration_seconds() -> float:
	if not _replay_controller:
		return 0.0
	return _replay_controller.get_duration_seconds()


func get_replay_events() -> Array[Dictionary]:
	if not _replay_controller:
		return []
	return _replay_controller.get_events()


func get_replay_playhead_seconds() -> float:
	if not _replay_controller:
		return 0.0
	return _replay_controller.get_playhead_seconds()


func get_replay_progress() -> float:
	if not _replay_controller:
		return 0.0
	return _replay_controller.get_progress()


func is_replay_playing() -> bool:
	return _replay_controller and _replay_controller.is_playing()


func is_replay_paused() -> bool:
	return _replay_controller and _replay_controller.is_playback_paused()


func save_replay_to_disk(path: String = replay_save_path) -> bool:
	if not _replay_controller:
		return false
	return _replay_controller.save_to_disk(path)


func load_replay_from_disk(path: String = replay_save_path) -> bool:
	if not _replay_controller:
		return false
	return _replay_controller.load_from_disk(path)


func start_replay() -> void:
	if not _replay_controller:
		return
	_replay_controller.enabled = replay_enabled
	_replay_controller.camera_mode = int(replay_camera_mode) as MatchReplayController.CameraMode
	_replay_controller.follow_offset = replay_follow_offset
	_replay_controller.start_playback()


func stop_replay() -> void:
	if _replay_controller:
		_replay_controller.stop_playback()


func pause_replay() -> void:
	if _replay_controller:
		_replay_controller.pause_playback()


func resume_replay() -> void:
	if _replay_controller:
		_replay_controller.resume_playback()


func toggle_replay_pause() -> void:
	if _replay_controller:
		_replay_controller.toggle_pause_playback()


func rewind_replay(seconds: float = 2.0) -> void:
	if _replay_controller:
		_replay_controller.rewind_seconds(seconds)


func forward_replay(seconds: float = 2.0) -> void:
	if _replay_controller:
		_replay_controller.forward_seconds(seconds)


func step_replay_frame(direction: int) -> void:
	if _replay_controller:
		_replay_controller.step_frame(direction)


func set_replay_camera_mode(mode: ReplayCameraMode) -> void:
	replay_camera_mode = mode
	if _replay_controller:
		_replay_controller.camera_mode = int(mode) as MatchReplayController.CameraMode


func get_replay_camera_mode() -> ReplayCameraMode:
	return replay_camera_mode


func _log_state_change(new_state: MatchState) -> void:
	var state_name: String = MatchState.keys()[new_state] if new_state < MatchState.size() else "UNKNOWN"
	DebugLogger.log(self, "State changed to: %s" % state_name)


