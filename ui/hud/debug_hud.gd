## Debug HUD for displaying match stats and player information during gameplay
extends CanvasLayer

const PLAYER_STATE_MACHINE_SCRIPT: Script = preload("res://player/state_machine.gd")
const MIN_SIM_SPEED: float = 0.1
const MAX_SIM_SPEED: float = 4.0
const SIM_SPEED_STEP: float = 0.1

## Reference to match manager for accessing game state
@export var match_manager: MatchManager

## Reference to trajectory drawer
@export var _trajectory_drawer: TrajectoryDrawer

# Tab containers and content
@warning_ignore("unused_private_class_variable")
@onready var _tab_container: TabContainer = $DebugHud/TabContainer

# Summary tab labels
@onready var _summary_fps_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/Performance/FPS
@onready var _summary_frame_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/Performance/Frame
@onready var _summary_frame_time_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/FrameTime/FrameValue
@onready var _summary_state_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/MatchState/Value
@onready var _summary_server_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/Server/Value
@onready var _summary_rally_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/Rally/Value
@onready var _summary_last_hitter_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/LastHitter/Value
@onready var _summary_serve_zone_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/ServeZone/Value
@onready var _summary_rally_zone_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/RallyZone/Value
@onready var _summary_ground_contacts_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/GroundContacts/Value
@onready var _summary_ball_position_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/Ball/Position
@onready var _summary_ball_velocity_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/BallVel/Value

# Player 0 summary labels
@onready var _summary_p0_name_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/P0Name/Value
@onready var _summary_p0_state_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/P0State/Value
@onready var _summary_p0_position_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/P0Position/Value
@onready var _summary_p0_velocity_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/P0Velocity/Value

# Player 1 summary labels
@onready var _summary_p1_name_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/P1Name/Value
@onready var _summary_p1_state_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/P1State/Value
@onready var _summary_p1_position_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/P1Position/Value
@onready var _summary_p1_velocity_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/P1Velocity/Value

# Trajectory toggle
@onready var _trajectory_button: CheckButton = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/TrajectoryToggle
@onready var _camera_selector: OptionButton = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/CameraSelect/CameraSelector
@onready var _sim_speed_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/SimSpeed/Value
@onready var _sim_pause_label: Label = $DebugHud/TabContainer/Summary/ScrollContainer/VBox/SimPaused/Value

# Performance labels
@onready var _fps_label: Label = $DebugHud/TabContainer/Performance/VBox/FPS/Value
@onready var _frametime_label: Label = $DebugHud/TabContainer/Performance/VBox/FrameTime/Value

# Match state labels
@onready var _match_state_label: Label = $DebugHud/TabContainer/Match/VBox/State/Value
@onready var _server_label: Label = $DebugHud/TabContainer/Match/VBox/Server/Value
@onready var _serve_zone_label: Label = $DebugHud/TabContainer/Match/VBox/ServeZone/Value
@onready var _rally_zone_label: Label = $DebugHud/TabContainer/Match/VBox/RallyZone/Value
@onready var _ground_contacts_label: Label = $DebugHud/TabContainer/Match/VBox/GroundContacts/Value
@onready var _last_hitter_label: Label = $DebugHud/TabContainer/Match/VBox/LastHitter/Value
@onready var _rally_length_label: Label = $DebugHud/TabContainer/Match/VBox/RallyLength/Value

# Player 0 stat labels
@onready var _p0_name_label: Label = $DebugHud/TabContainer/Player0/VBox/Name/Value
@onready var _p0_state_label: Label = $DebugHud/TabContainer/Player0/VBox/State/Value
@onready var _p0_position_label: Label = $DebugHud/TabContainer/Player0/VBox/Position/Value
@onready var _p0_velocity_label: Label = $DebugHud/TabContainer/Player0/VBox/Velocity/Value

# Player 1 stat labels
@onready var _p1_name_label: Label = $DebugHud/TabContainer/Player1/VBox/Name/Value
@onready var _p1_state_label: Label = $DebugHud/TabContainer/Player1/VBox/State/Value
@onready var _p1_position_label: Label = $DebugHud/TabContainer/Player1/VBox/Position/Value
@onready var _p1_velocity_label: Label = $DebugHud/TabContainer/Player1/VBox/Velocity/Value

# Ball stat labels
@onready var _ball_position_label: Label = $DebugHud/TabContainer/Ball/VBox/Position/Value
@onready var _ball_velocity_label: Label = $DebugHud/TabContainer/Ball/VBox/Velocity/Value

var _available_match_cameras: Array[Camera3D] = []


## Initialize debug HUD
func _ready() -> void:
	# Stay active while the scene tree is paused so shortcuts and display keep working
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Start hidden
	self.visible = false
	_trajectory_button.toggled.connect(_toggle_trajectory)
	_camera_selector.item_selected.connect(_on_camera_selected)
	_refresh_camera_selector()
	_refresh_simulation_labels()


## Handle debug menu toggle input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_debug_menu"):
		self.visible = not self.visible
		if self.visible:
			_refresh_camera_selector()
			_refresh_simulation_labels()
		return

	if not OS.is_debug_build():
		return

	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_COMMA:
			_change_simulation_speed(-SIM_SPEED_STEP)
			_refresh_simulation_labels()
		KEY_PERIOD:
			_change_simulation_speed(SIM_SPEED_STEP)
			_refresh_simulation_labels()
		KEY_MINUS:
			_set_simulation_speed(1.0)
			_refresh_simulation_labels()
		KEY_P:
			_toggle_simulation_pause()
			_refresh_simulation_labels()


## Update debug display each frame if visible
func _process(_delta: float) -> void:
	if visible:
		_update_performance_stats(_delta)
		_update_match_stats()
		_update_player_stats()
		_update_ball_stats()
		_update_summary_stats(_delta)


## Update performance metrics
func _update_performance_stats(_delta: float) -> void:
	var fps: int = int(Engine.get_frames_per_second())
	var frametime_ms: float = _delta * 1000.0

	_fps_label.text = str(fps)
	_frametime_label.text = "%.2f ms" % frametime_ms


## Update match state statistics display
func _update_match_stats() -> void:
	_match_state_label.text = _match_state_to_string(match_manager.current_state)
	_server_label.text = match_manager.get_server_name()

	_serve_zone_label.text = _court_region_to_string(match_manager.get_valid_serve_zone())
	_rally_zone_label.text = _court_region_to_string(match_manager.get_valid_rally_zone())
	_ground_contacts_label.text = str(match_manager.get_ground_contacts())
	_rally_length_label.text = str(match_manager.get_rally_length())
	_last_hitter_label.text = match_manager.get_last_hitter_name()


## Update player position, velocity, and stat displays
func _update_player_stats() -> void:
	# Player 0 stats
	var p0: Player = match_manager.player0
	_p0_name_label.text = p0.player_data.last_name
	var p0_state_text: String = _player_state_to_string(p0.get_current_state())
	if p0.controller is AiController:
		var ai_controller: AiController = p0.controller as AiController
		p0_state_text += " | AI: " + _ai_phase_to_string(ai_controller.get_current_phase())
	_p0_state_label.text = p0_state_text
	_p0_position_label.text = "%.2f, %.2f, %.2f" % [p0.position.x, p0.position.y, p0.position.z]
	_p0_velocity_label.text = "%.2f" % p0.velocity.length()

	# Player 1 stats
	var p1: Player = match_manager.player1
	_p1_name_label.text = p1.player_data.last_name
	var p1_state_text: String = _player_state_to_string(p1.get_current_state())
	if p1.controller is AiController:
		var ai_controller: AiController = p1.controller as AiController
		p1_state_text += " | AI: " + _ai_phase_to_string(ai_controller.get_current_phase())
	_p1_state_label.text = p1_state_text
	_p1_position_label.text = "%.2f, %.2f, %.2f" % [p1.position.x, p1.position.y, p1.position.z]
	_p1_velocity_label.text = "%.2f" % p1.velocity.length()


## Update ball position and velocity display
func _update_ball_stats() -> void:
	if match_manager.ball:
		var ball: Ball = match_manager.ball
		_ball_position_label.text = (
			"%.2f, %.2f, %.2f" % [ball.position.x, ball.position.y, ball.position.z]
		)
		_ball_velocity_label.text = "%.2f" % ball.velocity.length()


## Convert court region enum to human-readable string
func _court_region_to_string(value: Court.CourtRegion) -> String:
	var enum_map: Dictionary[Court.CourtRegion, String] = {
		Court.CourtRegion.LEFT_FRONT_SERVICE_BOX: "LEFT_FRONT_SERVICE_BOX",
		Court.CourtRegion.RIGHT_FRONT_SERVICE_BOX: "RIGHT_FRONT_SERVICE_BOX",
		Court.CourtRegion.LEFT_BACK_SERVICE_BOX: "LEFT_BACK_SERVICE_BOX",
		Court.CourtRegion.RIGHT_BACK_SERVICE_BOX: "RIGHT_BACK_SERVICE_BOX",
		Court.CourtRegion.BACK_SINGLES_BOX: "BACK_SINGLES_BOX",
		Court.CourtRegion.FRONT_SINGLES_BOX: "FRONT_SINGLES_BOX"
	}
	return enum_map.get(value, "UNKNOWN")


## Convert match state enum to human-readable string
func _match_state_to_string(value: MatchManager.MatchState) -> String:
	var enum_map: Dictionary[MatchManager.MatchState, String] = {
		MatchManager.MatchState.NOT_STARTED: "NOT_STARTED",
		MatchManager.MatchState.IDLE: "IDLE",
		MatchManager.MatchState.SERVE: "SERVE",
		MatchManager.MatchState.SECOND_SERVE: "SECOND_SERVE",
		MatchManager.MatchState.PLAY: "PLAY",
		MatchManager.MatchState.FAULT: "FAULT",
		MatchManager.MatchState.GAME_OVER: "GAME_OVER",
	}
	return enum_map.get(value, "UNKNOWN")


## Convert player state enum to human-readable string
func _player_state_to_string(value: int) -> String:
	var enum_map: Dictionary[int, String] = {
		PLAYER_STATE_MACHINE_SCRIPT.State.IDLE: "IDLE",
		PLAYER_STATE_MACHINE_SCRIPT.State.MOVING: "MOVING",
		PLAYER_STATE_MACHINE_SCRIPT.State.PREPARING_STROKE: "PREPARING_STROKE",
		PLAYER_STATE_MACHINE_SCRIPT.State.STROKING: "STROKING",
		PLAYER_STATE_MACHINE_SCRIPT.State.RECOVERING: "RECOVERING",
		PLAYER_STATE_MACHINE_SCRIPT.State.UNREACHABLE: "UNREACHABLE",
	}
	return enum_map.get(value, "UNKNOWN")


## Convert AI phase enum to human-readable string
func _ai_phase_to_string(value: AiController.Phase) -> String:
	var enum_map: Dictionary[AiController.Phase, String] = {
		AiController.Phase.ANTICIPATION: "ANTICIPATION",
		AiController.Phase.LOCK_IN: "LOCK_IN",
		AiController.Phase.TRACKING: "TRACKING",
		AiController.Phase.WAITING_FOR_HIT: "WAITING_FOR_HIT",
	}
	return enum_map.get(value, "UNKNOWN")


## Toggle ball trajectory drawing
func _toggle_trajectory(enabled: bool) -> void:
	if _trajectory_drawer:
		_trajectory_drawer.visible = enabled


## Update summary tab with key information from all systems
func _update_summary_stats(_delta: float) -> void:
	var fps: int = int(Engine.get_frames_per_second())
	var frametime_ms: float = _delta * 1000.0

	# Performance
	_summary_fps_label.text = str(fps)
	_summary_frame_label.text = "%.1fms" % frametime_ms
	_summary_frame_time_label.text = "%.2f ms" % frametime_ms

	# Match State
	_summary_state_label.text = _match_state_to_string(match_manager.current_state)
	_summary_server_label.text = match_manager.get_server_name()
	_summary_rally_label.text = str(match_manager.get_rally_length())
	_summary_last_hitter_label.text = match_manager.get_last_hitter_name()

	_summary_serve_zone_label.text = _court_region_to_string(match_manager.get_valid_serve_zone())
	_summary_rally_zone_label.text = _court_region_to_string(match_manager.get_valid_rally_zone())
	_summary_ground_contacts_label.text = str(match_manager.get_ground_contacts())

	# Ball
	if match_manager.ball:
		var ball: Ball = match_manager.ball
		_summary_ball_position_label.text = "%.2f, %.2f, %.2f" % [ball.position.x, ball.position.y, ball.position.z]
		_summary_ball_velocity_label.text = "%.2f" % ball.velocity.length()

	# Player 0
	var p0: Player = match_manager.player0
	_summary_p0_name_label.text = p0.player_data.last_name
	var p0_state_text: String = _player_state_to_string(p0.get_current_state())
	if p0.controller is AiController:
		var ai_controller: AiController = p0.controller as AiController
		p0_state_text += " | AI: " + _ai_phase_to_string(ai_controller.get_current_phase())
	_summary_p0_state_label.text = p0_state_text
	_summary_p0_position_label.text = "%.2f, %.2f, %.2f" % [p0.position.x, p0.position.y, p0.position.z]
	_summary_p0_velocity_label.text = "%.2f" % p0.velocity.length()

	# Player 1
	var p1: Player = match_manager.player1
	_summary_p1_name_label.text = p1.player_data.last_name
	var p1_state_text: String = _player_state_to_string(p1.get_current_state())
	if p1.controller is AiController:
		var ai_controller: AiController = p1.controller as AiController
		p1_state_text += " | AI: " + _ai_phase_to_string(ai_controller.get_current_phase())
	_summary_p1_state_label.text = p1_state_text
	_summary_p1_position_label.text = "%.2f, %.2f, %.2f" % [p1.position.x, p1.position.y, p1.position.z]
	_summary_p1_velocity_label.text = "%.2f" % p1.velocity.length()
	_refresh_simulation_labels()


func _refresh_camera_selector() -> void:
	_camera_selector.clear()
	_available_match_cameras.clear()

	if not match_manager or not match_manager.cameras:
		_camera_selector.add_item("No cameras")
		_camera_selector.disabled = true
		return

	var seen_ids: Dictionary = {}
	for camera in match_manager.cameras.cams:
		if camera == null:
			continue
		var id: int = camera.get_instance_id()
		if seen_ids.has(id):
			continue
		seen_ids[id] = true
		_available_match_cameras.append(camera)
		_camera_selector.add_item(camera.name)

	if _available_match_cameras.is_empty():
		_camera_selector.add_item("No cameras")
		_camera_selector.disabled = true
		return

	_camera_selector.disabled = false
	var selected_index: int = 0
	for i in _available_match_cameras.size():
		if _available_match_cameras[i].current:
			selected_index = i
			break
	_camera_selector.select(selected_index)


func _on_camera_selected(index: int) -> void:
	if index < 0 or index >= _available_match_cameras.size():
		return

	var camera: Camera3D = _available_match_cameras[index]
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return

	camera.make_current()

	if match_manager and match_manager.cameras:
		match_manager.cameras.active_cam = camera
		match_manager.cameras.active_cam_index = match_manager.cameras.cams.find(camera)


func _change_simulation_speed(delta_speed: float) -> void:
	var new_speed: float = clampf(Engine.time_scale + delta_speed, MIN_SIM_SPEED, MAX_SIM_SPEED)
	_set_simulation_speed(new_speed)


func _set_simulation_speed(new_speed: float) -> void:
	Engine.time_scale = clampf(new_speed, MIN_SIM_SPEED, MAX_SIM_SPEED)


func _toggle_simulation_pause() -> void:
	get_tree().paused = not get_tree().paused


func _refresh_simulation_labels() -> void:
	_sim_speed_label.text = "%.2fx" % Engine.time_scale
	_sim_pause_label.text = "YES" if get_tree().paused else "NO"
