## Debug HUD (toggled with the game_debug_menu action): match, ball and player state, a ball
## speed graph and the debug log. In debug builds , and . change the simulation speed, - resets
## it and P pauses. The mouse cursor shows while it is open.
extends CanvasLayer

const MIN_SIM_SPEED: float = 0.1
const MAX_SIM_SPEED: float = 4.0
const SIM_SPEED_STEP: float = 0.1
const BALL_SPEED_SAMPLE_INTERVAL: float = 0.1
const BALL_SPEED_COLOR := Color("#36a2eb")
const ALL_OBJECTS := "All Objects"

@export var match_manager: MatchManager
@export var _trajectory_drawer: TrajectoryDrawer

var _ball_speed_function: Function
var _ball_speed_elapsed: float = 0.0
var _ball_speed_sample_accumulator: float = 0.0
var _log_text_filter: String = ""
var _log_object_filter: String = ""
var _log_display_dirty: bool = true
var _shown_log_count: int = 0

@onready var _summary: VBoxContainer = $DebugHud/TabContainer/Summary/ScrollContainer/VBox
@onready var _fps_label: Label = _summary.get_node("Performance/FPS")
@onready var _frame_label: Label = _summary.get_node("Performance/Frame")
@onready var _state_label: Label = _summary.get_node("MatchState/Value")
@onready var _server_label: Label = _summary.get_node("Server/Value")
@onready var _rally_label: Label = _summary.get_node("Rally/Value")
@onready var _last_hitter_label: Label = _summary.get_node("LastHitter/Value")
@onready var _serve_zone_label: Label = _summary.get_node("ServeZone/Value")
@onready var _rally_zone_label: Label = _summary.get_node("RallyZone/Value")
@onready var _ground_contacts_label: Label = _summary.get_node("GroundContacts/Value")
@onready var _ball_position_label: Label = _summary.get_node("Ball/Position")
@onready var _ball_velocity_label: Label = _summary.get_node("BallVel/Value")
@onready var _player_labels: Array[Dictionary] = [
	{
		"name": _summary.get_node("P0Name/Value"),
		"state": _summary.get_node("P0State/Value"),
		"position": _summary.get_node("P0Position/Value"),
		"velocity": _summary.get_node("P0Velocity/Value"),
	},
	{
		"name": _summary.get_node("P1Name/Value"),
		"state": _summary.get_node("P1State/Value"),
		"position": _summary.get_node("P1Position/Value"),
		"velocity": _summary.get_node("P1Velocity/Value"),
	},
]
@onready var _trajectory_button: CheckButton = _summary.get_node("TrajectoryToggle")
@onready var _camera_selector: OptionButton = _summary.get_node("CameraSelect/CameraSelector")
@onready var _sim_speed_label: Label = _summary.get_node("SimSpeed/Value")
@onready var _sim_pause_label: Label = _summary.get_node("SimPaused/Value")
@onready var _ball_speed_plot: Chart = $DebugHud/TabContainer/Ball/VBox/BallSpeedGraph
@onready var _log_filter_input: LineEdit = $DebugHud/TabContainer/Logs/FilterContainer/FilterInput
@onready
var _log_object_dropdown: OptionButton = $DebugHud/TabContainer/Logs/FilterContainer/ObjectFilter
@onready var _log_clear_button: Button = $DebugHud/TabContainer/Logs/FilterContainer/ClearButton
@onready var _log_display: TextEdit = $DebugHud/TabContainer/Logs/LogDisplay


func _ready() -> void:
	# Stay active while the scene tree is paused so shortcuts and display keep working
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for labels in _player_labels:
		labels.state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match_manager.active_ball_changed.connect(_reset_ball_speed_history.unbind(1))
	_trajectory_button.toggled.connect(_trajectory_drawer.set_visible)
	_trajectory_drawer.visible = _trajectory_button.button_pressed
	_camera_selector.item_selected.connect(_on_camera_selected)
	_setup_ball_speed_plot()
	_log_filter_input.text_changed.connect(_on_log_filter_changed)
	_log_clear_button.pressed.connect(_on_log_clear_pressed)
	_log_object_dropdown.item_selected.connect(_on_log_object_filter_changed)
	_log_object_dropdown.add_item(ALL_OBJECTS)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_debug_menu"):
		visible = not visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_HIDDEN
		if visible:
			_refresh_camera_selector()
		return

	if not OS.is_debug_build() or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_COMMA:
			_set_simulation_speed(Engine.time_scale - SIM_SPEED_STEP)
		KEY_PERIOD:
			_set_simulation_speed(Engine.time_scale + SIM_SPEED_STEP)
		KEY_MINUS:
			_set_simulation_speed(1.0)
		KEY_P:
			get_tree().paused = not get_tree().paused


func _process(delta: float) -> void:
	if not visible:
		return
	_update_summary(delta)
	if not get_tree().paused and match_manager.ball:
		_record_ball_speed_sample(match_manager.ball.velocity.length(), delta)
	_update_log_display()


func _update_summary(delta: float) -> void:
	_fps_label.text = str(Engine.get_frames_per_second())
	_frame_label.text = "%.1fms" % (delta * 1000.0)

	_state_label.text = MatchManager.MatchState.keys()[match_manager.current_state]
	_server_label.text = match_manager.get_server().player_data.last_name
	_rally_label.text = str(match_manager.match_data.rally_length)
	var last_hitter: Player = match_manager.last_hitter
	_last_hitter_label.text = last_hitter.player_data.last_name if last_hitter else "None"
	_serve_zone_label.text = Court.CourtRegion.keys()[match_manager.valid_serve_zone]
	_rally_zone_label.text = Court.CourtRegion.keys()[match_manager.valid_rally_zone]
	_ground_contacts_label.text = str(match_manager.ground_contacts)

	var ball: Ball = match_manager.ball
	if ball:
		_ball_position_label.text = _format_vector(ball.position)
		_ball_velocity_label.text = "%.2f" % ball.velocity.length()

	for i in _player_labels.size():
		var player: Player = match_manager.get_player(i)
		var labels: Dictionary = _player_labels[i]
		labels.name.text = player.player_data.last_name
		labels.state.text = _player_debug_text(player)
		labels.position.text = _format_vector(player.position)
		labels.velocity.text = "%.2f" % player.velocity.length()

	_sim_speed_label.text = "%.2fx" % Engine.time_scale
	_sim_pause_label.text = "YES" if get_tree().paused else "NO"


func _player_debug_text(player: Player) -> String:
	var stamina: float = player.get_stamina_ratio()
	var lines: PackedStringArray = [
		"State: %s" % PlayerStateMachine.State.keys()[player.get_current_state()]
	]
	if player.controller is AiController:
		var phase: AiController.Phase = (player.controller as AiController).get_current_phase()
		lines.append("AI: %s" % AiController.Phase.keys()[phase])
	lines.append("Stamina: %d%%" % int(stamina * 100.0))
	lines.append(
		(
			"Speed×: %.2f | Accel×: %.2f"
			% [
				player.stats.movement_speed_multiplier(stamina),
				player.stats.acceleration_multiplier(stamina)
			]
		)
	)
	lines.append(
		(
			"Confidence: %.2f | Pressure: %.2f"
			% [player.mental_state.confidence, player.mental_state.pressure]
		)
	)
	lines.append("Ball:\n%s" % _player_ball_text(player))
	lines.append("Queued Stroke:\n%s" % _queued_stroke_text(player.queued_stroke))
	return "\n".join(lines)


func _player_ball_text(player: Player) -> String:
	if not is_instance_valid(player.ball):
		return "NONE"
	var status: String = "ACTIVE" if player.ball == match_manager.ball else "STALE"
	return (
		"%s\n  id=%d\n  pos=%s"
		% [status, player.ball.get_instance_id(), _format_vector(player.ball.position)]
	)


func _queued_stroke_text(stroke: Stroke) -> String:
	if not stroke:
		return "NONE"
	var step_time: String = "%.2f" % stroke.step.time if stroke.step else "-"
	var step_bounces: String = str(stroke.step.bounces) if stroke.step else "-"
	return (
		(
			"%s\n  intended_power=%.2f actual_power=%.2f\n  intended_target=(%s)"
			+ "\n  actual_target=(%s)\n  spin=(%s)\n  step_t=%s bounces=%s"
		)
		% [
			Stroke.StrokeType.keys()[stroke.stroke_type],
			stroke.intended_stroke_power,
			stroke.stroke_power,
			_format_vector(stroke.intended_stroke_target),
			_format_vector(stroke.stroke_target),
			_format_vector(stroke.stroke_spin),
			step_time,
			step_bounces,
		]
	)


func _format_vector(vector: Vector3) -> String:
	return "%.2f, %.2f, %.2f" % [vector.x, vector.y, vector.z]


func _refresh_camera_selector() -> void:
	_camera_selector.clear()
	for camera in match_manager.cameras.cams:
		_camera_selector.add_item(camera.name)
		if camera.current:
			_camera_selector.select(_camera_selector.item_count - 1)


func _on_camera_selected(index: int) -> void:
	match_manager.cameras.activate(match_manager.cameras.cams[index])


func _set_simulation_speed(new_speed: float) -> void:
	Engine.time_scale = clampf(new_speed, MIN_SIM_SPEED, MAX_SIM_SPEED)


func _setup_ball_speed_plot() -> void:
	var chart_theme := Theme.new()
	chart_theme.set_color("text_color", "Chart", Color.WHITE)
	chart_theme.set_color("tick_color", "Chart", Color.WHITE)
	chart_theme.set_color("origin_color", "Chart", Color.WHITE)
	chart_theme.set_color("tick_grid_line_color", "Chart", Color(0.3, 0.3, 0.3, 1.0))
	var chart_area := StyleBoxFlat.new()
	chart_area.draw_center = false
	chart_area.set_content_margin_all(15)
	chart_theme.set_stylebox("chart_area", "Chart", chart_area)
	var plot_area := StyleBoxFlat.new()
	plot_area.draw_center = false
	plot_area.set_border_width_all(0)
	chart_theme.set_stylebox("plot_area", "Chart", plot_area)
	chart_theme.set_stylebox("panel", "Chart", StyleBoxEmpty.new())
	_ball_speed_plot.theme = chart_theme
	_reset_ball_speed_history()


func _reset_ball_speed_history() -> void:
	_ball_speed_elapsed = 0.0
	_ball_speed_sample_accumulator = 0.0
	_ball_speed_function = Function.new(
		[0.0, 0.001],
		[0.0, 0.0],
		"Speed",
		{color = BALL_SPEED_COLOR, marker = Function.Marker.NONE, type = Function.Type.AREA}
	)
	var properties := ChartProperties.new()
	properties.title = ""
	properties.x_label = "Time (s)"
	properties.y_label = "Speed (m/s)"
	properties.show_title = false
	properties.show_legend = false
	properties.interactive = false
	properties.max_samples = 240
	_ball_speed_plot.plot([_ball_speed_function], properties)


func _record_ball_speed_sample(ball_speed: float, delta: float) -> void:
	_ball_speed_elapsed += delta
	_ball_speed_sample_accumulator += delta
	if _ball_speed_sample_accumulator >= BALL_SPEED_SAMPLE_INTERVAL:
		_ball_speed_function.add_point(_ball_speed_elapsed, ball_speed)
		_ball_speed_sample_accumulator = 0.0
		_ball_speed_plot.queue_redraw()


func _on_log_filter_changed(new_filter: String) -> void:
	_log_text_filter = new_filter.to_lower()
	_log_display_dirty = true


func _on_log_object_filter_changed(index: int) -> void:
	_log_object_filter = "" if index == 0 else _log_object_dropdown.get_item_text(index)
	_log_display_dirty = true


func _on_log_clear_pressed() -> void:
	DebugLogger.clear_logs()
	_log_display_dirty = true


## Adds the objects that appeared in the log since the last refresh to the object filter.
func _refresh_object_filter(logs: Array[Dictionary]) -> void:
	var known: PackedStringArray = []
	for i in _log_object_dropdown.item_count:
		known.append(_log_object_dropdown.get_item_text(i))
	for entry in logs:
		if not known.has(entry.object_name):
			known.append(entry.object_name)
			_log_object_dropdown.add_item(entry.object_name)


func _update_log_display() -> void:
	var logs: Array[Dictionary] = DebugLogger.get_logs()
	if not _log_display_dirty and logs.size() == _shown_log_count:
		return
	_shown_log_count = logs.size()
	_log_display_dirty = false
	_refresh_object_filter(logs)

	var lines: PackedStringArray = []
	for entry in logs:
		if not _log_object_filter.is_empty() and entry.object_name != _log_object_filter:
			continue
		if (
			not _log_text_filter.is_empty()
			and not entry.message.to_lower().contains(_log_text_filter)
		):
			continue
		var relative_ms: int = entry.timestamp - DebugLogger.get_start_time_ms()
		var seconds: int = floori(relative_ms / 1000.0)
		lines.append(
			(
				"[%02d:%02d.%03d] %s: %s"
				% [
					floori(seconds / 60.0),
					seconds % 60,
					relative_ms % 1000,
					entry.object_name,
					entry.message
				]
			)
		)
	_log_display.text = "\n".join(lines)
	_log_display.set_caret_line(_log_display.get_line_count() - 1)
