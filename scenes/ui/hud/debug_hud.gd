## Debug HUD for displaying match stats and player information during gameplay
extends CanvasLayer

const MIN_SIM_SPEED: float = 0.1
const MAX_SIM_SPEED: float = 4.0
const SIM_SPEED_STEP: float = 0.1
const BALL_SPEED_SAMPLE_INTERVAL: float = 0.1

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
@onready var _ball_speed_plot: PanelContainer = $DebugHud/TabContainer/Ball/VBox/BallSpeedGraph

# Logs tab elements
@onready var _log_filter_input: LineEdit = $DebugHud/TabContainer/Logs/FilterContainer/FilterInput
@onready var _log_clear_button: Button = $DebugHud/TabContainer/Logs/FilterContainer/ClearButton
@onready var _log_display: TextEdit = $DebugHud/TabContainer/Logs/LogDisplay
@onready var _log_object_filter_dropdown: OptionButton = $DebugHud/TabContainer/Logs/FilterContainer/ObjectFilter
@onready var _log_object_filter: OptionButton = $DebugHud/TabContainer/Logs/FilterContainer/ObjectFilter

var _available_match_cameras: Array[Camera3D] = []
var _ball_speed_dataset = null
var _ball_speed_series_id: int = -1
var _ball_speed_elapsed: float = 0.0
var _ball_speed_sample_accumulator: float = 0.0

# Log filtering
var _current_text_filter: String = ""
var _current_object_filter: String = ""
var _log_display_dirty: bool = true
var _last_log_count: int = 0


## Initialize debug HUD
func _ready() -> void:
	# Stay active while the scene tree is paused so shortcuts and display keep working
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Start hidden
	self.visible = false
	_configure_multiline_labels()
	if match_manager and not match_manager.active_ball_changed.is_connected(_on_active_ball_changed):
		match_manager.active_ball_changed.connect(_on_active_ball_changed)
	_trajectory_button.toggled.connect(_toggle_trajectory)
	_camera_selector.item_selected.connect(_on_camera_selected)
	_setup_ball_speed_plot()
	_reset_ball_speed_history()
	
	# Connect log tab controls
	_log_filter_input.text_changed.connect(_on_log_filter_changed)
	_log_clear_button.pressed.connect(_on_log_clear_pressed)
	if _log_object_filter_dropdown:
		_log_object_filter_dropdown.item_selected.connect(_on_log_object_filter_changed)
		_log_object_filter_dropdown.add_item("All Objects", 0)
	
	# Debug: verify log UI is ready
	print("DebugHUD: Log UI initialized - filter: %s, display: %s" % [_log_filter_input != null, _log_display != null])
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
		_update_ball_stats(_delta)
		_update_summary_stats(_delta)
		_update_log_display()


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
	_p0_state_label.text = _format_player_debug_block(p0)
	_p0_position_label.text = "%.2f, %.2f, %.2f" % [p0.position.x, p0.position.y, p0.position.z]
	_p0_velocity_label.text = "%.2f" % p0.velocity.length()

	# Player 1 stats
	var p1: Player = match_manager.player1
	_p1_name_label.text = p1.player_data.last_name
	_p1_state_label.text = _format_player_debug_block(p1)
	_p1_position_label.text = "%.2f, %.2f, %.2f" % [p1.position.x, p1.position.y, p1.position.z]
	_p1_velocity_label.text = "%.2f" % p1.velocity.length()


## Update ball position and velocity display
func _update_ball_stats(delta: float) -> void:
	if get_tree().paused:
		return

	var ball: Ball = match_manager.get_active_ball()
	if ball:
		_ball_position_label.text = (
			"%.2f, %.2f, %.2f" % [ball.position.x, ball.position.y, ball.position.z]
		)
		var ball_speed: float = ball.velocity.length()
		_ball_velocity_label.text = "%.2f" % ball_speed
		_record_ball_speed_sample(ball_speed, delta)


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
	var enum_map: Dictionary[PlayerStateMachine.State, String] = {
		PlayerStateMachine.State.IDLE: "IDLE",
		PlayerStateMachine.State.MOVING: "MOVING",
		PlayerStateMachine.State.PREPARING_STROKE: "PREPARING_STROKE",
		PlayerStateMachine.State.STROKING: "STROKING",
		PlayerStateMachine.State.RECOVERING: "RECOVERING",
		PlayerStateMachine.State.UNREACHABLE: "UNREACHABLE",
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


func _stroke_type_to_string(value: Stroke.StrokeType) -> String:
	var enum_map: Dictionary[Stroke.StrokeType, String] = {
		Stroke.StrokeType.FOREHAND: "FOREHAND",
		Stroke.StrokeType.FOREHAND_DROP_SHOT: "FOREHAND_DROP_SHOT",
		Stroke.StrokeType.BACKHAND: "BACKHAND",
		Stroke.StrokeType.SERVE: "SERVE",
		Stroke.StrokeType.BACKHAND_SLICE: "BACKHAND_SLICE",
		Stroke.StrokeType.BACKHAND_DROP_SHOT: "BACKHAND_DROP_SHOT",
		Stroke.StrokeType.VOLLEY: "VOLLEY",
	}
	return enum_map.get(value, "UNKNOWN")


func _queued_stroke_to_string(player: Player) -> String:
	if player == null or player.queued_stroke == null:
		return "NONE"

	var stroke: Stroke = player.queued_stroke
	var step_time: String = "-"
	var step_bounces: String = "-"
	if stroke.step:
		step_time = "%.2f" % stroke.step.time
		step_bounces = str(stroke.step.bounces)

	return "%s\n  intended_power=%.2f actual_power=%.2f delay=%.2f\n  intended_target=(%.2f, %.2f, %.2f)\n  actual_target=(%.2f, %.2f, %.2f)\n  spin=(%.2f, %.2f, %.2f)\n  step_t=%s bounces=%s" % [
		_stroke_type_to_string(stroke.stroke_type),
		stroke.intended_stroke_power,
		stroke.stroke_power,
		stroke.delay,
		stroke.intended_stroke_target.x,
		stroke.intended_stroke_target.y,
		stroke.intended_stroke_target.z,
		stroke.stroke_target.x,
		stroke.stroke_target.y,
		stroke.stroke_target.z,
		stroke.stroke_spin.x,
		stroke.stroke_spin.y,
		stroke.stroke_spin.z,
		step_time,
		step_bounces,
	]


func _player_ball_to_string(player: Player) -> String:
	if player == null or not is_instance_valid(player.ball):
		return "NONE"

	var player_ball: Ball = player.ball
	var ball_status: String = "ACTIVE" if player_ball == match_manager.get_active_ball() else "STALE"
	return "%s\n  id=%s\n  pos=(%.2f, %.2f, %.2f)" % [
		ball_status,
		str(player_ball.get_instance_id()),
		player_ball.position.x,
		player_ball.position.y,
		player_ball.position.z,
	]


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
	var ball: Ball = match_manager.get_active_ball()
	if ball:
		_summary_ball_position_label.text = "%.2f, %.2f, %.2f" % [ball.position.x, ball.position.y, ball.position.z]
		_summary_ball_velocity_label.text = "%.2f" % ball.velocity.length()

	# Player 0
	var p0: Player = match_manager.player0
	_summary_p0_name_label.text = p0.player_data.last_name
	_summary_p0_state_label.text = _format_player_debug_block(p0)
	_summary_p0_position_label.text = "%.2f, %.2f, %.2f" % [p0.position.x, p0.position.y, p0.position.z]
	_summary_p0_velocity_label.text = "%.2f" % p0.velocity.length()

	# Player 1
	var p1: Player = match_manager.player1
	_summary_p1_name_label.text = p1.player_data.last_name
	_summary_p1_state_label.text = _format_player_debug_block(p1)
	_summary_p1_position_label.text = "%.2f, %.2f, %.2f" % [p1.position.x, p1.position.y, p1.position.z]
	_summary_p1_velocity_label.text = "%.2f" % p1.velocity.length()
	_refresh_simulation_labels()


func _format_player_debug_block(player: Player) -> String:
	var lines: PackedStringArray = []
	lines.append("State: %s" % _player_state_to_string(player.get_current_state()))
	if player.controller is AiController:
		var ai_controller: AiController = player.controller as AiController
		lines.append("AI: %s" % _ai_phase_to_string(ai_controller.get_current_phase()))
	if player.stats:
		var stamina_pct: int = int(player.get_stamina_ratio() * 100.0)
		lines.append("Stamina: %d%%" % stamina_pct)
		lines.append("Speed×: %.2f | Accel×: %.2f" % [
			player.stats.movement_speed_multiplier(player.get_stamina_ratio()),
			player.stats.acceleration_multiplier(player.get_stamina_ratio())
		])
	if player.mental_state:
		lines.append("Confidence: %.2f | Pressure: %.2f" % [
			player.mental_state.confidence,
			player.mental_state.pressure
		])
	lines.append("Ball:\n%s" % _player_ball_to_string(player))
	lines.append("Queued Stroke:\n%s" % _queued_stroke_to_string(player))
	return "\n".join(lines)


func _configure_multiline_labels() -> void:
	var labels: Array[Label] = [
		_p0_state_label,
		_p1_state_label,
		_summary_p0_state_label,
		_summary_p1_state_label,
	]

	for label in labels:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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


func _on_active_ball_changed(_ball: Ball) -> void:
	_reset_ball_speed_history()


func _setup_ball_speed_plot() -> void:
	if _ball_speed_plot == null:
		return

	var x_axis: TauAxisConfig = TauAxisConfig.new()
	x_axis.title = "Time (s)"
	x_axis.include_zero_in_domain = true
	x_axis.tick_count_preferred = 6

	var y_axis: TauAxisConfig = TauAxisConfig.new()
	y_axis.title = "Speed"
	y_axis.include_zero_in_domain = true
	y_axis.tick_count_preferred = 5

	var scatter_cfg: TauScatterConfig = TauScatterConfig.new()
	scatter_cfg.style.marker_size_px = 4.0
	scatter_cfg.style.hovered_marker_size_px = 4.0

	var grid: TauGridLineConfig = TauGridLineConfig.new()
	grid.x_major_enabled = true
	grid.y_major_enabled = true

	var pane: TauPaneConfig = TauPaneConfig.new()
	pane.y_left_axis = y_axis
	pane.overlays = [scatter_cfg]
	pane.grid_line = grid

	var config: TauXYConfig = TauXYConfig.new()
	config.x_axis = x_axis
	config.panes = [pane]

	var dataset := TauPlot.Dataset.make_shared_x_continuous(
		PackedStringArray(["Speed"]),
		PackedFloat64Array([0.0]),
		[PackedFloat64Array([0.0])] as Array[PackedFloat64Array],
		240
	)
	if dataset == null:
		push_error("Failed to initialize ball speed plot dataset")
		return

	_ball_speed_dataset = dataset
	_ball_speed_series_id = _ball_speed_dataset.get_series_id_by_index(0)

	var binding: TauXYSeriesBinding = TauXYSeriesBinding.new()
	binding.series_id = _ball_speed_series_id
	binding.pane_index = 0
	binding.overlay_type = TauXYSeriesBinding.PaneOverlayType.SCATTER
	binding.y_axis_id = TauPlot.AxisId.LEFT

	var bindings: Array[TauXYSeriesBinding] = [binding]

	_ball_speed_plot.title = "Ball Speed"
	_ball_speed_plot.legend_enabled = false
	_ball_speed_plot.hover_enabled = false
	_ball_speed_plot.plot_xy(_ball_speed_dataset, config, bindings)


func _reset_ball_speed_history() -> void:
	_ball_speed_elapsed = 0.0
	_ball_speed_sample_accumulator = 0.0
	if _ball_speed_dataset == null:
		return

	_ball_speed_dataset.clear_samples()
	_ball_speed_dataset.append_shared_sample(0.0, PackedFloat64Array([0.0]))


func _record_ball_speed_sample(ball_speed: float, delta: float) -> void:
	if _ball_speed_dataset == null or _ball_speed_series_id < 0:
		return

	_ball_speed_elapsed += maxf(delta, 0.0)
	_ball_speed_sample_accumulator += maxf(delta, 0.0)

	var sample_count: int = _ball_speed_dataset.get_shared_sample_count()
	if sample_count == 0:
		_ball_speed_dataset.append_shared_sample(_ball_speed_elapsed, PackedFloat64Array([ball_speed]))
		_ball_speed_sample_accumulator = 0.0
		return

	var last_sample_index: int = sample_count - 1
	if _ball_speed_sample_accumulator >= BALL_SPEED_SAMPLE_INTERVAL:
		_ball_speed_dataset.append_shared_sample(_ball_speed_elapsed, PackedFloat64Array([ball_speed]))
		_ball_speed_sample_accumulator = 0.0
		return

	_ball_speed_dataset.set_series_y(_ball_speed_series_id, last_sample_index, ball_speed)


## Helper to get DebugLogger autoload
func _get_logger():
	return DebugLogger


## Log a message from any object
func log_strategy_message(sender: Object, message: String) -> void:
	var logger = _get_logger()
	if logger and logger.has_method("log"):
		logger.log(sender, message)
	_log_display_dirty = true


## Filter callback for log input
func _on_log_filter_changed(new_filter: String) -> void:
	_current_text_filter = new_filter.to_lower()
	_log_display_dirty = true


## Filter callback for object dropdown
func _on_log_object_filter_changed(index: int) -> void:
	if index == 0:
		_current_object_filter = ""
	else:
		var text = _log_object_filter.get_item_text(index)
		_current_object_filter = text
	_log_display_dirty = true


## Clear logs callback
func _on_log_clear_pressed() -> void:
	var logger = _get_logger()
	if logger and logger.has_method("clear_logs"):
		logger.clear_logs()
	_log_display_dirty = true


## Refresh object filter dropdown with current objects in logs
func _refresh_object_filter() -> void:
	if not _log_object_filter_dropdown:
		return
	
	var logger = _get_logger()
	if not logger:
		return
	
	# Only refresh if object names have changed
	if not logger.has_method("have_object_names_changed") or not logger.have_object_names_changed():
		return
	
	# Save current selection
	var current_object = _current_object_filter
	
	_log_object_filter_dropdown.clear()
	_log_object_filter_dropdown.add_item("All Objects", 0)
	
	var object_names = logger.get_object_names() if logger.has_method("get_object_names") else PackedStringArray()
	for i in range(object_names.size()):
		_log_object_filter_dropdown.add_item(object_names[i], i + 1)
	
	# Restore selection
	if current_object.is_empty():
		_log_object_filter_dropdown.select(0)
	else:
		# Find and select the object
		for i in range(_log_object_filter_dropdown.get_item_count()):
			if _log_object_filter_dropdown.get_item_text(i) == current_object:
				_log_object_filter_dropdown.select(i)
				break


## Update log display with filtered entries
func _update_log_display() -> void:
	var logger = _get_logger()
	if not logger:
		return
	
	# Get current log count
	var logs = logger.get_logs() if logger.has_method("get_logs") else []
	var current_log_count = logs.size()
	
	# Check if display needs updating (new logs or filter changed)
	var needs_update = _log_display_dirty or current_log_count != _last_log_count
	if not needs_update:
		return
	
	_last_log_count = current_log_count
	
	if not _log_display or not is_instance_valid(_log_display):
		return
	
	# Refresh object filter options (only if names changed)
	_refresh_object_filter()
	
	var display_text: String = ""
	var text_filter_lower: String = _current_text_filter.to_lower()
	var start_time_ms: int = logger.get_start_time_ms() if logger.has_method("get_start_time_ms") else 0
	
	for entry in logs:
		var object_name: String = entry["object_name"]
		var message: String = entry["message"]
		var timestamp_ms: int = entry["timestamp"]
		
		# Apply object filter
		if not _current_object_filter.is_empty() and object_name != _current_object_filter:
			continue
		
		# Apply text filter
		if not text_filter_lower.is_empty() and not message.to_lower().contains(text_filter_lower):
			continue
		
		# Calculate relative time from start
		var relative_ms: int = timestamp_ms - start_time_ms
		if relative_ms < 0:
			relative_ms = 0  # Safety check
		
		# Format timestamp as MM:SS.ms
		var seconds: int = int(relative_ms / 1000.0)
		var milliseconds: int = relative_ms % 1000
		var time_str: String = "%02d:%02d.%03d" % [int(seconds / 60.0), seconds % 60, milliseconds]
		
		display_text += "[%s] %s: %s\n" % [time_str, object_name, message]
	
	_log_display.text = display_text
	# Scroll to bottom
	_log_display.set_caret_line(_log_display.get_line_count() - 1)
	_log_display_dirty = false
