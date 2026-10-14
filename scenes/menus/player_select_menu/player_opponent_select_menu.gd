extends Control
## Player select menu. Every connected input device is shown in the device lanes (see
## DeviceLanes): moving a device left or right gives it control of that player; a player
## without a device is AI controlled. A device on a side picks that side's character with up
## and down and confirms with its accept button (A / Enter). The start button gets the focus
## once every human player has confirmed. Cancel (B / Esc) on a confirmed device takes the
## confirmation back; otherwise it leaves the menu.
## In training and for a tournament only player 1 is picked, and a device has to control it.

signal selection_confirmed

## What the players are picked for
enum Mode {
	MATCH,
	TRAINING,
	TOURNAMENT,
}

const PLAYER1_CHART_COLOR := Palette.PLAYER_1
const PLAYER2_CHART_COLOR := Palette.PLAYER_2
const READY_COLOR := Palette.AMBER

@export var chart_scene: PackedScene
## What the players are picked for: a match picks both, a training and a tournament the
## player's own.
@export var mode: Mode = Mode.MATCH

var _players: Array[PlayerData] = []
var _chart: Chart

@onready var player_option_button: OptionButton = %PlayerOptionButton
@onready var opponent_option_button: OptionButton = %OpponentOptionButton
@onready var player1_header_label: Label = %Player1HeaderLabel
@onready var player2_header_label: Label = %Player2HeaderLabel
@onready var player1_control_label: Label = %Player1ControlLabel
@onready var player2_control_label: Label = %Player2ControlLabel
@onready var selected_player_label: Label = %SelectedPlayerLabel
@onready var selected_opponent_label: Label = %SelectedOpponentLabel
@onready var device_lanes: DeviceLanes = %DeviceLanes
@onready var chart_host: Control = %ChartHost
@onready var start_button: Button = %StartButton
@onready var title_label: Label = %TitleLabel
@onready var devices_hint_label: Label = %DevicesHintLabel
@onready var opponent_select_column: Control = %OpponentSelectColumn


func _ready() -> void:
	if _picks_one_player():
		_apply_one_player_layout()
	_players = GlobalGameData.get_players()
	_populate_option_buttons()
	_apply_player_colors()
	_build_chart()
	device_lanes.changed.connect(_refresh_control_labels)
	device_lanes.character_step_requested.connect(_cycle_character)
	player_option_button.item_selected.connect(_on_player_selected)
	opponent_option_button.item_selected.connect(_on_opponent_selected)
	player_option_button.get_popup().popup_hide.connect(_update_start_focus)
	opponent_option_button.get_popup().popup_hide.connect(_update_start_focus)
	_refresh_view()
	_refresh_control_labels()


func _input(event: InputEvent) -> void:
	if event.is_action("ui_cancel") and device_lanes.handle_cancel(event):
		get_viewport().set_input_as_handled()
		return
	# Until everybody confirmed nothing has the focus; keep accept presses from reaching other
	# menus.
	if event.is_action("ui_accept") and get_viewport().gui_get_focus_owner() == null:
		get_viewport().set_input_as_handled()


func _populate_option_buttons() -> void:
	player_option_button.clear()
	opponent_option_button.clear()
	for p in _players:
		var display_name := "%s %s" % [p.first_name, p.last_name]
		player_option_button.add_item(display_name)
		opponent_option_button.add_item(display_name)
	player_option_button.select(0)
	opponent_option_button.select(1)


func _picks_one_player() -> bool:
	return mode != Mode.MATCH


## Training and tournament: only the player's side, and its device lane.
func _apply_one_player_layout() -> void:
	if mode == Mode.TRAINING:
		title_label.text = "Training"
		devices_hint_label.text = ("Move a controller left to train with it, then confirm with A / Enter")
		start_button.text = "Start Training"
	else:
		title_label.text = Tournament.NAME
		devices_hint_label.text = "Move a controller left to play with it, then confirm with A / Enter"
		start_button.text = "Start %s" % Tournament.NAME
	device_lanes.one_player = true
	opponent_select_column.hide()


func _apply_player_colors() -> void:
	player1_header_label.add_theme_color_override("font_color", PLAYER1_CHART_COLOR)
	player2_header_label.add_theme_color_override("font_color", PLAYER2_CHART_COLOR)
	selected_player_label.add_theme_color_override("font_color", PLAYER1_CHART_COLOR)
	selected_opponent_label.add_theme_color_override("font_color", PLAYER2_CHART_COLOR)


## Device lanes
##################


func _refresh_control_labels() -> void:
	_refresh_control_label(player1_control_label, DeviceLanes.Lane.PLAYER1)
	_refresh_control_label(player2_control_label, DeviceLanes.Lane.PLAYER2)
	_update_start_focus()


func _refresh_control_label(label: Label, lane: DeviceLanes.Lane) -> void:
	label.text = _control_text(lane)
	if device_lanes.is_lane_confirmed(lane):
		label.add_theme_color_override("font_color", READY_COLOR)
	else:
		label.remove_theme_color_override("font_color")


func _control_text(lane: DeviceLanes.Lane) -> String:
	var device_name: String = device_lanes.get_lane_device_name(lane)
	if device_name.is_empty():
		return "CPU"
	if device_lanes.is_lane_confirmed(lane):
		return "%s - READY" % device_name
	return "%s - press A / Enter to confirm" % device_name


## Focuses the start button once every human player confirmed (right away without humans). A
## training or a tournament can only start once a device controls the player.
func _update_start_focus() -> void:
	start_button.disabled = (
		_picks_one_player()
		and device_lanes.get_lane_device_id(DeviceLanes.Lane.PLAYER1) == InputDevice.NO_DEVICE_ID
	)
	if start_button.disabled or not device_lanes.are_sides_confirmed():
		start_button.release_focus()
		return
	start_button.grab_focus()


## Character selection
########################


## Cycles the character of the side `lane`.
func _cycle_character(lane: DeviceLanes.Lane, step: int) -> void:
	match lane:
		DeviceLanes.Lane.PLAYER1:
			_select_character(player_option_button, opponent_option_button, step)
			_on_player_selected(player_option_button.selected)
		DeviceLanes.Lane.PLAYER2:
			_select_character(opponent_option_button, player_option_button, step)
			_on_opponent_selected(opponent_option_button.selected)


## Selects the next character in `step` direction that the other side has not picked.
func _select_character(button: OptionButton, other_button: OptionButton, step: int) -> void:
	var index: int = posmod(button.selected + step, _players.size())
	if index == other_button.selected:
		index = posmod(index + step, _players.size())
	button.select(index)


func _on_player_selected(index: int) -> void:
	if index == opponent_option_button.selected:
		opponent_option_button.select((index + 1) % _players.size())
	_refresh_view()


func _on_opponent_selected(index: int) -> void:
	if index == player_option_button.selected:
		player_option_button.select((index + 1) % _players.size())
	_refresh_view()


func _refresh_view() -> void:
	var player := _players[player_option_button.selected]
	var opponent := _players[opponent_option_button.selected]

	selected_player_label.text = _player_summary(player)
	selected_opponent_label.text = _player_summary(opponent)
	_plot_stats(player, opponent)


func _player_summary(player_data: PlayerData) -> String:
	return (
		"#%s  %s %s\n%s  |  %scm  |  %sH"
		% [
			str(player_data.rank),
			player_data.first_name,
			player_data.last_name,
			player_data.country,
			str(player_data.height),
			player_data.hand,
		]
	)


## Stats chart
################


func _build_chart() -> void:
	_chart = chart_scene.instantiate()
	_chart.name = "StatsRadarChart"
	_chart.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chart.mouse_filter = Control.MOUSE_FILTER_PASS
	var transparent_style := StyleBoxEmpty.new()

	# Easy Charts uses these theme styleboxes internally when plotting.
	_chart.add_theme_stylebox_override("panel", transparent_style)
	_chart.add_theme_stylebox_override("normal", transparent_style)
	_chart.add_theme_stylebox_override("chart_area", transparent_style)
	_chart.add_theme_stylebox_override("plot_area", transparent_style)

	var canvas := _chart.get_node_or_null("Canvas") as PanelContainer
	if canvas:
		canvas.add_theme_stylebox_override("panel", transparent_style)
	chart_host.add_child(_chart)


func _plot_stats(player_data: PlayerData, opponent_data: PlayerData) -> void:
	var x_values: Array = [
		"Serve", "Serve Acc", "Forehand", "Backhand", "Speed", "Agility", "Stamina", "Focus"
	]
	var player_values: Array = _extract_chart_stats(player_data.stats)
	var opponent_values: Array = _extract_chart_stats(opponent_data.stats)

	var range_min: float = player_values.min() - 10.0
	var range_max: float = minf(player_values.max() + 10.0, 100.0)
	if range_max <= range_min:
		range_max = range_min + 1.0

	var player_function := Function.new(
		x_values,
		player_values,
		"player1",
		_radar_style(PLAYER1_CHART_COLOR, Function.Marker.CIRCLE, range_min, range_max)
	)
	var opponent_function := Function.new(
		x_values,
		opponent_values,
		"player2",
		_radar_style(PLAYER2_CHART_COLOR, Function.Marker.CROSS, range_min, range_max)
	)

	var chart_properties := ChartProperties.new()
	chart_properties.title = ""
	chart_properties.show_legend = false
	chart_properties.show_x_label = false
	chart_properties.show_y_label = false
	chart_properties.draw_vertical_grid = false
	chart_properties.draw_horizontal_grid = false
	chart_properties.draw_ticks = false
	chart_properties.draw_grid_box = false
	chart_properties.draw_bounding_box = false
	chart_properties.interactive = true
	chart_properties.draw_frame = false
	chart_properties.draw_background = false
	chart_properties.colors.frame = Color(0.0, 0.0, 0.0, 0.0)
	chart_properties.colors.background = Color(0.0, 0.0, 0.0, 0.0)

	var functions: Array[Function] = [player_function]
	if not _picks_one_player():
		functions.append(opponent_function)
	_chart.plot(functions, chart_properties)


func _radar_style(
	color: Color, marker: Function.Marker, range_min: float, range_max: float
) -> Dictionary:
	return {
		color = color,
		marker = marker,
		type = Function.Type.RADAR,
		radar_fill_alpha = 0.20,
		radar_grid_levels = 5,
		radar_grid_color = Color(Palette.CREAM, 0.35),
		radar_axis_color = Color(Palette.CREAM, 0.35),
		radar_label_color = Palette.CREAM,
		radar_scale_label_color = Palette.CREAM,
		radar_show_scale_labels = true,
		radar_min_value = range_min,
		radar_max_value = range_max,
		line_width = 2.0
	}


func _extract_chart_stats(stats: PlayerStatsProfile) -> Array:
	return [
		stats.serve_power,
		stats.serve_accuracy,
		stats.forehand,
		stats.backhand,
		stats.top_speed,
		stats.agility,
		stats.stamina,
		stats.focus,
	]


func _on_start_button_pressed() -> void:
	var player: PlayerData = _players[player_option_button.selected]
	match mode:
		Mode.MATCH:
			GlobalGameData.set_match_players(player, _players[opponent_option_button.selected])
		Mode.TRAINING:
			GlobalGameData.set_training_player(player)
		Mode.TOURNAMENT:
			GlobalGameData.start_tournament(player)
	GlobalGameData.set_match_input_devices(
		device_lanes.get_lane_device_id(DeviceLanes.Lane.PLAYER1),
		device_lanes.get_lane_device_id(DeviceLanes.Lane.PLAYER2)
	)
	selection_confirmed.emit()
