extends Control

signal selection_confirmed

const PLAYER1_CHART_COLOR := Color("#36A2EB")
const PLAYER2_CHART_COLOR := Color("#FF6384")

const INPUT_METHOD_LABELS := ["AI", "Human"]
const LEFT_AXIS_ASSIGN_THRESHOLD := -0.65
const RIGHT_AXIS_ASSIGN_THRESHOLD := 0.65
const AXIS_NEUTRAL_THRESHOLD := 0.25

@export var chart_scene: PackedScene
var _players: Array[PlayerData] = []
var _chart: Chart
var _connected_device_ids: Array[int] = []
var _player_device_assignments: Array[int] = [
	GlobalGameData.NO_DEVICE_ID, GlobalGameData.NO_DEVICE_ID
]
var _device_axis_neutral: Dictionary = {}

@onready var player_option_button: OptionButton = %PlayerOptionButton
@onready var opponent_option_button: OptionButton = %OpponentOptionButton
@onready var player1_input_method_option_button: OptionButton = %Player1InputMethodOptionButton
@onready var player2_input_method_option_button: OptionButton = %Player2InputMethodOptionButton
@onready var connected_devices_option_button: OptionButton = %ConnectedDevicesOptionButton
@onready var player1_header_label: Label = %Player1HeaderLabel
@onready var player2_header_label: Label = %Player2HeaderLabel
@onready var selected_player_label: Label = %SelectedPlayerLabel
@onready var selected_opponent_label: Label = %SelectedOpponentLabel
@onready var chart_host: Control = %ChartHost
@onready var start_button: Button = %StartButton


func _ready() -> void:
	_players = _load_players()
	_initialize_default_input_assignments()
	_populate_connected_devices_option_button()
	_populate_input_method_option_buttons()
	_populate_option_buttons()
	_ensure_distinct_defaults()
	_apply_player_colors()
	_build_chart()
	_connect_signals()
	_refresh_view()


func _initialize_default_input_assignments() -> void:
	_player_device_assignments = [GlobalGameData.NO_DEVICE_ID, GlobalGameData.NO_DEVICE_ID]
	GlobalGameData.set_match_input_methods(
		GlobalGameData.InputMethod.AI, GlobalGameData.InputMethod.AI
	)
	GlobalGameData.set_match_input_devices(GlobalGameData.NO_DEVICE_ID, GlobalGameData.NO_DEVICE_ID)


func _load_players() -> Array[PlayerData]:
	GlobalGameData.load_players()
	return GlobalGameData.get_players()


func _populate_input_method_option_buttons() -> void:
	player1_input_method_option_button.clear()
	player2_input_method_option_button.clear()

	for label in INPUT_METHOD_LABELS:
		player1_input_method_option_button.add_item(label)
		player2_input_method_option_button.add_item(label)

	var selected_methods: Array[int] = GlobalGameData.get_match_input_methods()
	player1_input_method_option_button.select(
		clampi(selected_methods[0], 0, INPUT_METHOD_LABELS.size() - 1)
	)
	player2_input_method_option_button.select(
		clampi(selected_methods[1], 0, INPUT_METHOD_LABELS.size() - 1)
	)


func _populate_connected_devices_option_button() -> void:
	connected_devices_option_button.clear()
	_connected_device_ids.clear()
	_device_axis_neutral.clear()

	connected_devices_option_button.add_item("Keyboard")
	_connected_device_ids.append(GlobalGameData.KEYBOARD_DEVICE_ID)

	var connected_joypads: Array = Input.get_connected_joypads()
	connected_devices_option_button.disabled = false
	for joypad_id_variant in connected_joypads:
		var joypad_id: int = int(joypad_id_variant)
		var joypad_name: String = Input.get_joy_name(joypad_id)
		var label := "Device %d" % joypad_id
		if not joypad_name.is_empty():
			label += " - %s" % joypad_name
		connected_devices_option_button.add_item(label)
		_connected_device_ids.append(joypad_id)
		_device_axis_neutral[joypad_id] = true

	connected_devices_option_button.select(0)


func _apply_player_colors() -> void:
	player1_header_label.add_theme_color_override("font_color", PLAYER1_CHART_COLOR)
	player2_header_label.add_theme_color_override("font_color", PLAYER2_CHART_COLOR)
	selected_player_label.add_theme_color_override("font_color", PLAYER1_CHART_COLOR)
	selected_opponent_label.add_theme_color_override("font_color", PLAYER2_CHART_COLOR)


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


func _ensure_distinct_defaults() -> void:
	if _players.is_empty():
		return

	player_option_button.select(0)
	if _players.size() > 1:
		opponent_option_button.select(1)
	else:
		opponent_option_button.select(0)


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


func _connect_signals() -> void:
	player_option_button.item_selected.connect(_on_player_selected)
	opponent_option_button.item_selected.connect(_on_opponent_selected)
	player1_input_method_option_button.item_selected.connect(_on_player1_input_method_selected)
	player2_input_method_option_button.item_selected.connect(_on_player2_input_method_selected)
	connected_devices_option_button.item_selected.connect(_on_connected_device_selected)


func _on_player_selected(index: int) -> void:
	if _players.size() > 1 and index == opponent_option_button.selected:
		opponent_option_button.select((index + 1) % _players.size())
	_refresh_view()


func _on_opponent_selected(index: int) -> void:
	if _players.size() > 1 and index == player_option_button.selected:
		player_option_button.select((index + 1) % _players.size())
	_refresh_view()


func _on_player1_input_method_selected(index: int) -> void:
	if index == GlobalGameData.InputMethod.AI:
		_player_device_assignments[0] = -1
	_save_input_selection_state()


func _on_player2_input_method_selected(index: int) -> void:
	if index == GlobalGameData.InputMethod.AI:
		_player_device_assignments[1] = -1
	_save_input_selection_state()


func _on_connected_device_selected(_index: int) -> void:
	# Selection is consumed via directional input in _unhandled_input.
	pass


func _unhandled_input(event: InputEvent) -> void:
	if connected_devices_option_button.disabled:
		return

	if event is InputEventJoypadMotion:
		_handle_joypad_motion(event as InputEventJoypadMotion)
	elif event is InputEventJoypadButton:
		_handle_joypad_button(event as InputEventJoypadButton)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


func _handle_joypad_motion(motion_event: InputEventJoypadMotion) -> void:
	if motion_event.axis != JOY_AXIS_LEFT_X:
		return
	if not _is_selected_device_event(motion_event.device):
		return

	var axis_value: float = motion_event.axis_value
	var was_neutral := bool(_device_axis_neutral.get(motion_event.device, true))
	if absf(axis_value) <= AXIS_NEUTRAL_THRESHOLD:
		_device_axis_neutral[motion_event.device] = true
		return
	if not was_neutral:
		return

	if axis_value <= LEFT_AXIS_ASSIGN_THRESHOLD:
		_assign_selected_device_to_slot(0)
		_device_axis_neutral[motion_event.device] = false
	elif axis_value >= RIGHT_AXIS_ASSIGN_THRESHOLD:
		_assign_selected_device_to_slot(1)
		_device_axis_neutral[motion_event.device] = false


func _handle_joypad_button(button_event: InputEventJoypadButton) -> void:
	if not button_event.pressed:
		return
	if not _is_selected_device_event(button_event.device):
		return

	if button_event.button_index == JOY_BUTTON_DPAD_LEFT:
		_assign_selected_device_to_slot(0)
	elif button_event.button_index == JOY_BUTTON_DPAD_RIGHT:
		_assign_selected_device_to_slot(1)


func _handle_key(key_event: InputEventKey) -> void:
	if not key_event.pressed or key_event.echo:
		return
	if not _is_keyboard_selected():
		return

	if key_event.keycode == KEY_A or key_event.keycode == KEY_LEFT:
		_assign_selected_device_to_slot(0)
	elif key_event.keycode == KEY_D or key_event.keycode == KEY_RIGHT:
		_assign_selected_device_to_slot(1)


func _is_selected_device_event(device_id: int) -> bool:
	if connected_devices_option_button.selected < 0:
		return false
	if connected_devices_option_button.selected >= _connected_device_ids.size():
		return false
	return _connected_device_ids[connected_devices_option_button.selected] == device_id


func _is_keyboard_selected() -> bool:
	if connected_devices_option_button.selected < 0:
		return false
	if connected_devices_option_button.selected >= _connected_device_ids.size():
		return false
	return (
		_connected_device_ids[connected_devices_option_button.selected]
		== GlobalGameData.KEYBOARD_DEVICE_ID
	)


func _assign_selected_device_to_slot(slot_index: int) -> void:
	if connected_devices_option_button.selected < 0:
		return
	if connected_devices_option_button.selected >= _connected_device_ids.size():
		return

	var selected_device_id: int = _connected_device_ids[connected_devices_option_button.selected]
	var other_slot: int = 1 - slot_index

	if _player_device_assignments[other_slot] == selected_device_id:
		_player_device_assignments[other_slot] = GlobalGameData.NO_DEVICE_ID
		if other_slot == 0:
			player1_input_method_option_button.select(GlobalGameData.InputMethod.AI)
		else:
			player2_input_method_option_button.select(GlobalGameData.InputMethod.AI)

	_player_device_assignments[slot_index] = selected_device_id
	if slot_index == 0:
		player1_input_method_option_button.select(GlobalGameData.InputMethod.HUMAN)
	else:
		player2_input_method_option_button.select(GlobalGameData.InputMethod.HUMAN)

	_save_input_selection_state()


func _save_input_selection_state() -> void:
	GlobalGameData.set_match_input_methods(
		player1_input_method_option_button.selected, player2_input_method_option_button.selected
	)

	if player1_input_method_option_button.selected != GlobalGameData.InputMethod.HUMAN:
		_player_device_assignments[0] = GlobalGameData.NO_DEVICE_ID
	if player2_input_method_option_button.selected != GlobalGameData.InputMethod.HUMAN:
		_player_device_assignments[1] = GlobalGameData.NO_DEVICE_ID

	GlobalGameData.set_match_input_devices(
		_player_device_assignments[0], _player_device_assignments[1]
	)


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

	var player := _players[player_option_button.selected]
	var opponent := _players[opponent_option_button.selected]
	_save_input_selection_state()
	GlobalGameData.set_match_players(player, opponent)
	selection_confirmed.emit()
