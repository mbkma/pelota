extends Control
## Player select menu. Every connected input device is shown as an icon in the middle column.
## Moving a device left or right (stick, d-pad, WASD or arrow keys) gives it control of that
## player; a player without a device is AI controlled. A device on a side picks that side's
## character with up and down.

signal selection_confirmed

enum Lane {
	PLAYER1,
	UNASSIGNED,
	PLAYER2,
}

const PLAYER1_CHART_COLOR := Color("#36A2EB")
const PLAYER2_CHART_COLOR := Color("#FF6384")
const UNASSIGNED_COLOR := Color.WHITE

## Direction length that triggers a menu step.
const DIRECTION_TRIGGER: float = 0.6
## Direction length below which the device counts as neutral again.
const DIRECTION_RELEASE: float = 0.3
const DEVICE_ICON_SIZE := Vector2(48, 48)
const DEVICE_CARD_WIDTH: float = 140.0


## One input device and its place in the device lanes.
class DeviceEntry:
	var device: InputDevice
	var lane: Lane = Lane.UNASSIGNED
	## Row with one slot per lane; the card sits in the slot of its lane.
	var row: HBoxContainer
	var card: VBoxContainer
	var icon: TextureRect
	## Set after a step until the direction returns to neutral.
	var latched: bool = false


@export var chart_scene: PackedScene
@export var keyboard_icon: Texture2D
@export var gamepad_icon: Texture2D

var _players: Array[PlayerData] = []
var _chart: Chart
var _entries: Array[DeviceEntry] = []

@onready var player_option_button: OptionButton = %PlayerOptionButton
@onready var opponent_option_button: OptionButton = %OpponentOptionButton
@onready var player1_header_label: Label = %Player1HeaderLabel
@onready var player2_header_label: Label = %Player2HeaderLabel
@onready var player1_control_label: Label = %Player1ControlLabel
@onready var player2_control_label: Label = %Player2ControlLabel
@onready var selected_player_label: Label = %SelectedPlayerLabel
@onready var selected_opponent_label: Label = %SelectedOpponentLabel
@onready var device_rows: VBoxContainer = %DeviceRows
@onready var chart_host: Control = %ChartHost
@onready var start_button: Button = %StartButton


func _ready() -> void:
	GlobalGameData.load_players()
	_players = GlobalGameData.get_players()
	_populate_option_buttons()
	_apply_player_colors()
	_build_chart()
	_rebuild_device_entries()
	player_option_button.item_selected.connect(_on_player_selected)
	opponent_option_button.item_selected.connect(_on_opponent_selected)
	player_option_button.get_popup().popup_hide.connect(start_button.grab_focus)
	opponent_option_button.get_popup().popup_hide.connect(start_button.grab_focus)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_view()
	# The start button keeps the focus, so ui_accept on any device starts the match.
	start_button.grab_focus()


func _process(_delta: float) -> void:
	for entry in _entries:
		entry.device.poll()
		var direction: Vector2 = entry.device.get_direction()
		if entry.latched:
			entry.latched = direction.length() >= DIRECTION_RELEASE
			continue

		if absf(direction.x) >= DIRECTION_TRIGGER and absf(direction.x) >= absf(direction.y):
			_move_entry(entry, int(signf(direction.x)))
			entry.latched = true
		elif absf(direction.y) >= DIRECTION_TRIGGER:
			# Up selects the previous character in the list.
			_cycle_character(entry, -int(signf(direction.y)))
			entry.latched = true


func _populate_option_buttons() -> void:
	player_option_button.clear()
	opponent_option_button.clear()
	for p in _players:
		var display_name := "%s %s" % [p.first_name, p.last_name]
		player_option_button.add_item(display_name)
		opponent_option_button.add_item(display_name)

	var has_any_players: bool = _players.size() > 0
	player_option_button.disabled = not has_any_players
	opponent_option_button.disabled = not has_any_players
	start_button.disabled = not has_any_players
	if not has_any_players:
		return

	player_option_button.select(0)
	opponent_option_button.select(1 if _players.size() > 1 else 0)


func _apply_player_colors() -> void:
	player1_header_label.add_theme_color_override("font_color", PLAYER1_CHART_COLOR)
	player2_header_label.add_theme_color_override("font_color", PLAYER2_CHART_COLOR)
	selected_player_label.add_theme_color_override("font_color", PLAYER1_CHART_COLOR)
	selected_opponent_label.add_theme_color_override("font_color", PLAYER2_CHART_COLOR)


## Device lanes
##################


## Rebuilds the device rows from the connected devices, keeping known devices in their lanes.
func _rebuild_device_entries() -> void:
	var previous_lanes: Dictionary[int, Lane] = {}
	for entry in _entries:
		previous_lanes[entry.device.get_device_id()] = entry.lane
		entry.row.queue_free()
	_entries.clear()

	for device_id in InputDevice.get_connected_device_ids():
		var entry := _create_entry(InputDevice.create(device_id))
		entry.lane = previous_lanes.get(device_id, Lane.UNASSIGNED)
		# Stay latched so a direction held while plugging in does not move the device.
		entry.latched = true
		_entries.append(entry)
		_place_card(entry)
	_refresh_control_labels()


func _create_entry(device: InputDevice) -> DeviceEntry:
	var entry := DeviceEntry.new()
	entry.device = device

	entry.row = HBoxContainer.new()
	for lane in Lane.values():
		var slot := CenterContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size.x = DEVICE_CARD_WIDTH
		entry.row.add_child(slot)
	device_rows.add_child(entry.row)

	entry.card = VBoxContainer.new()
	entry.card.alignment = BoxContainer.ALIGNMENT_CENTER
	entry.icon = TextureRect.new()
	entry.icon.texture = keyboard_icon if device is KeyboardInput else gamepad_icon
	entry.icon.custom_minimum_size = DEVICE_ICON_SIZE
	entry.icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	entry.icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	entry.icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	entry.card.add_child(entry.icon)

	var name_label := Label.new()
	name_label.text = device.get_display_name()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = DEVICE_CARD_WIDTH
	entry.card.add_child(name_label)
	return entry


## Moves a device one lane left (step -1) or right (step 1). A side holds one device.
func _move_entry(entry: DeviceEntry, step: int) -> void:
	var target: Lane = clampi(entry.lane + step, Lane.PLAYER1, Lane.PLAYER2) as Lane
	if target == entry.lane:
		return
	if target != Lane.UNASSIGNED and _get_lane_entry(target):
		return
	entry.lane = target
	_place_card(entry)
	_refresh_control_labels()


func _place_card(entry: DeviceEntry) -> void:
	var slot: Node = entry.row.get_child(entry.lane)
	if entry.card.get_parent():
		entry.card.reparent(slot, false)
	else:
		slot.add_child(entry.card)
	entry.icon.modulate = _lane_color(entry.lane)


func _get_lane_entry(lane: Lane) -> DeviceEntry:
	for entry in _entries:
		if entry.lane == lane:
			return entry
	return null


func _get_lane_device_id(lane: Lane) -> int:
	var entry: DeviceEntry = _get_lane_entry(lane)
	return entry.device.get_device_id() if entry else InputDevice.NO_DEVICE_ID


func _lane_color(lane: Lane) -> Color:
	match lane:
		Lane.PLAYER1:
			return PLAYER1_CHART_COLOR
		Lane.PLAYER2:
			return PLAYER2_CHART_COLOR
	return UNASSIGNED_COLOR


func _refresh_control_labels() -> void:
	player1_control_label.text = _control_text(Lane.PLAYER1)
	player2_control_label.text = _control_text(Lane.PLAYER2)


func _control_text(lane: Lane) -> String:
	var entry: DeviceEntry = _get_lane_entry(lane)
	return entry.device.get_display_name() if entry else "CPU"


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_rebuild_device_entries()


## Character selection
########################


## Cycles the character of the side the device controls. Devices in the middle do nothing.
func _cycle_character(entry: DeviceEntry, step: int) -> void:
	if _players.is_empty():
		return
	match entry.lane:
		Lane.PLAYER1:
			_select_character(player_option_button, opponent_option_button, step)
			_on_player_selected(player_option_button.selected)
		Lane.PLAYER2:
			_select_character(opponent_option_button, player_option_button, step)
			_on_opponent_selected(opponent_option_button.selected)


## Selects the next character in `step` direction that the other side has not picked.
func _select_character(button: OptionButton, other_button: OptionButton, step: int) -> void:
	var index: int = posmod(button.selected + step, _players.size())
	if index == other_button.selected and _players.size() > 1:
		index = posmod(index + step, _players.size())
	button.select(index)


func _on_player_selected(index: int) -> void:
	if _players.size() > 1 and index == opponent_option_button.selected:
		opponent_option_button.select((index + 1) % _players.size())
	_refresh_view()


func _on_opponent_selected(index: int) -> void:
	if _players.size() > 1 and index == player_option_button.selected:
		player_option_button.select((index + 1) % _players.size())
	_refresh_view()


func _refresh_view() -> void:
	if _players.is_empty():
		selected_player_label.text = "No player1 available"
		selected_opponent_label.text = "No player2 available"
		return

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
	_chart = chart_scene.instantiate() as Chart
	if _chart == null:
		push_error("Failed to instantiate Easy Charts chart scene")
		return
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

	var player_min: float = _array_min(player_values)
	var player_max: float = _array_max(player_values)
	var range_min: float = player_min - 10.0
	var range_max: float = minf(player_max + 10.0, 100.0)
	if range_max <= range_min:
		range_max = range_min + 1.0

	var player_function = Function.new(
		x_values,
		player_values,
		"player1",
		{
			color = PLAYER1_CHART_COLOR,
			marker = Function.Marker.CIRCLE,
			type = Function.Type.RADAR,
			radar_fill_alpha = 0.20,
			radar_grid_levels = 5,
			radar_grid_color = Color("#d9d9d9"),
			radar_axis_color = Color("#d9d9d9"),
			radar_label_color = Color.WHITE,
			radar_scale_label_color = Color.WHITE,
			radar_show_scale_labels = true,
			radar_min_value = range_min,
			radar_max_value = range_max,
			line_width = 2.0
		}
	)
	var opponent_function = Function.new(
		x_values,
		opponent_values,
		"player2",
		{
			color = PLAYER2_CHART_COLOR,
			marker = Function.Marker.CROSS,
			type = Function.Type.RADAR,
			radar_fill_alpha = 0.20,
			radar_grid_levels = 5,
			radar_grid_color = Color("#d9d9d9"),
			radar_axis_color = Color("#d9d9d9"),
			radar_label_color = Color.WHITE,
			radar_scale_label_color = Color.WHITE,
			radar_show_scale_labels = true,
			radar_min_value = range_min,
			radar_max_value = range_max,
			line_width = 2.0
		}
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

	_chart.plot([player_function, opponent_function], chart_properties)


func _extract_chart_stats(stats: PlayerStatsProfile) -> Array:
	if stats == null:
		return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

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


func _array_min(values: Array) -> float:
	if values.is_empty():
		return 0.0

	var min_value: float = float(values[0])
	for value in values:
		min_value = minf(min_value, float(value))
	return min_value


func _array_max(values: Array) -> float:
	if values.is_empty():
		return 0.0

	var max_value: float = float(values[0])
	for value in values:
		max_value = maxf(max_value, float(value))
	return max_value


func _on_start_button_pressed() -> void:
	if _players.is_empty():
		return

	GlobalGameData.set_match_players(
		_players[player_option_button.selected], _players[opponent_option_button.selected]
	)
	GlobalGameData.set_match_input_devices(
		_get_lane_device_id(Lane.PLAYER1), _get_lane_device_id(Lane.PLAYER2)
	)
	selection_confirmed.emit()
