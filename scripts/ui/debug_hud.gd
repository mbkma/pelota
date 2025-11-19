## Debug HUD for displaying match stats and player information during gameplay
extends CanvasLayer

## Reference to match manager for accessing game state
@export var match_manager: MatchManager

## Reference to trajectory drawer
@export var _trajectory_drawer: TrajectoryDrawer

# Tab containers and content
@onready var _tab_container: TabContainer = $DebugHud/TabContainer

# Summary tab labels
@onready var _summary_fps_label: Label = $DebugHud/TabContainer/Summary/VBox/Performance/FPS
@onready var _summary_frame_label: Label = $DebugHud/TabContainer/Summary/VBox/Performance/Frame
@onready var _summary_state_label: Label = $DebugHud/TabContainer/Summary/VBox/MatchState/Value
@onready var _summary_server_label: Label = $DebugHud/TabContainer/Summary/VBox/Server/Value
@onready var _summary_rally_label: Label = $DebugHud/TabContainer/Summary/VBox/Rally/Value
@onready var _summary_last_hitter_label: Label = $DebugHud/TabContainer/Summary/VBox/LastHitter/Value
@onready var _summary_ball_position_label: Label = $DebugHud/TabContainer/Summary/VBox/Ball/Position
@onready var _summary_ball_velocity_label: Label = $DebugHud/TabContainer/Summary/VBox/Ball/BallVel

# Trajectory toggle
@onready var _trajectory_button: CheckButton = $DebugHud/TabContainer/Summary/VBox/TrajectoryToggle

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
@onready var _p0_position_label: Label = $DebugHud/TabContainer/Player0/VBox/Position/Value
@onready var _p0_velocity_label: Label = $DebugHud/TabContainer/Player0/VBox/Velocity/Value

# Player 1 stat labels
@onready var _p1_name_label: Label = $DebugHud/TabContainer/Player1/VBox/Name/Value
@onready var _p1_position_label: Label = $DebugHud/TabContainer/Player1/VBox/Position/Value
@onready var _p1_velocity_label: Label = $DebugHud/TabContainer/Player1/VBox/Velocity/Value

# Ball stat labels
@onready var _ball_position_label: Label = $DebugHud/TabContainer/Ball/VBox/Position/Value
@onready var _ball_velocity_label: Label = $DebugHud/TabContainer/Ball/VBox/Velocity/Value


## Initialize debug HUD
func _ready() -> void:
	# Start hidden
	self.visible = false
	_trajectory_button.toggled.connect(_toggle_trajectory)


## Handle debug menu toggle input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_debug_menu"):
		self.visible = not self.visible


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
	var fps: int = Engine.get_frames_per_second()
	var frametime_ms: float = _delta * 1000.0

	_fps_label.text = str(fps)
	_frametime_label.text = "%.2f ms" % frametime_ms


## Update match state statistics display
func _update_match_stats() -> void:
	_match_state_label.text = _match_state_to_string(match_manager.current_state)

	var server_idx: int = match_manager.match_data.match_score.current_server
	var server_name: String = (
		match_manager.player0.player_data.last_name
		if server_idx == 0
		else match_manager.player1.player_data.last_name
	)
	_server_label.text = server_name

	_serve_zone_label.text = _court_region_to_string(match_manager._valid_serve_zone)
	_rally_zone_label.text = _court_region_to_string(match_manager._valid_rally_zone)
	_ground_contacts_label.text = str(match_manager._ground_contacts)
	_rally_length_label.text = str(match_manager.match_data.rally_length)

	if match_manager.last_hitter:
		_last_hitter_label.text = match_manager.last_hitter.player_data.last_name
	else:
		_last_hitter_label.text = "None"


## Update player position, velocity, and stat displays
func _update_player_stats() -> void:
	# Player 0 stats
	var p0: Player = match_manager.player0
	_p0_name_label.text = p0.player_data.last_name
	_p0_position_label.text = "%.2f, %.2f, %.2f" % [p0.position.x, p0.position.y, p0.position.z]
	_p0_velocity_label.text = "%.2f" % p0.velocity.length()

	# Player 1 stats
	var p1: Player = match_manager.player1
	_p1_name_label.text = p1.player_data.last_name
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


## Toggle ball trajectory drawing
func _toggle_trajectory(enabled: bool) -> void:
	if _trajectory_drawer:
		_trajectory_drawer.visible = enabled


## Update summary tab with key information from all systems
func _update_summary_stats(_delta: float) -> void:
	var fps: int = Engine.get_frames_per_second()
	var frametime_ms: float = _delta * 1000.0

	_summary_fps_label.text = str(fps)
	_summary_frame_label.text = "%.1fms" % frametime_ms

	_summary_state_label.text = _match_state_to_string(match_manager.current_state)

	var server_idx: int = match_manager.match_data.match_score.current_server
	var server_name: String = (
		match_manager.player0.player_data.last_name
		if server_idx == 0
		else match_manager.player1.player_data.last_name
	)
	_summary_server_label.text = server_name

	_summary_rally_label.text = str(match_manager.match_data.rally_length)

	if match_manager.last_hitter:
		_summary_last_hitter_label.text = match_manager.last_hitter.player_data.last_name
	else:
		_summary_last_hitter_label.text = "None"

	if match_manager.ball:
		var ball: Ball = match_manager.ball
		_summary_ball_position_label.text = "%.1f, %.1f" % [ball.position.x, ball.position.z]
		_summary_ball_velocity_label.text = "%.1f" % ball.velocity.length()
