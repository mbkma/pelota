extends Control

signal selection_confirmed

@export var chart_scene: PackedScene
const CHARACTER_DATA_DIR := "res://assets/resources/characters"
const PLAYER1_CHART_COLOR := Color("#36A2EB")
const PLAYER2_CHART_COLOR := Color("#FF6384")

@onready var player_option_button: OptionButton = %PlayerOptionButton
@onready var opponent_option_button: OptionButton = %OpponentOptionButton
@onready var player1_input_method_option_button: OptionButton = %Player1InputMethodOptionButton
@onready var player2_input_method_option_button: OptionButton = %Player2InputMethodOptionButton
@onready var player1_header_label: Label = %Player1HeaderLabel
@onready var player2_header_label: Label = %Player2HeaderLabel
@onready var selected_player_label: Label = %SelectedPlayerLabel
@onready var selected_opponent_label: Label = %SelectedOpponentLabel
@onready var chart_host: Control = %ChartHost
@onready var start_button: Button = %StartButton

var _players: Array[PlayerData] = []
var _chart: Chart


func _ready() -> void:
	_players = _load_players()
	_populate_input_method_option_buttons()
	_populate_option_buttons()
	_ensure_distinct_defaults()
	_apply_player_colors()
	_build_chart()
	_connect_signals()
	_refresh_view()


func _load_players() -> Array[PlayerData]:
	var loaded_players_by_path: Dictionary = {}

	for entry in GlobalScenes.PLAYER_DATA:
		if entry is PlayerData:
			var global_player_data := entry as PlayerData
			if global_player_data.resource_path.is_empty():
				loaded_players_by_path[str(loaded_players_by_path.size())] = global_player_data
			else:
				loaded_players_by_path[global_player_data.resource_path] = global_player_data

	var directory := DirAccess.open(CHARACTER_DATA_DIR)
	if directory:
		directory.list_dir_begin()
		var file_name := directory.get_next()
		while file_name != "":
			if not directory.current_is_dir() and file_name.get_extension().to_lower() == "tres":
				var resource_path := "%s/%s" % [CHARACTER_DATA_DIR, file_name]
				var loaded_resource := load(resource_path)
				if loaded_resource is PlayerData:
					loaded_players_by_path[resource_path] = loaded_resource as PlayerData
			file_name = directory.get_next()
		directory.list_dir_end()

	var result: Array[PlayerData] = []
	for player_data in loaded_players_by_path.values():
		result.append(player_data as PlayerData)

	result.sort_custom(func(a: PlayerData, b: PlayerData) -> bool: return a.rank < b.rank)
	return result


func _populate_input_method_option_buttons() -> void:
	var labels := ["AI", "Human"]
	player1_input_method_option_button.clear()
	player2_input_method_option_button.clear()

	for label in labels:
		player1_input_method_option_button.add_item(label)
		player2_input_method_option_button.add_item(label)

	var selected_methods: Array[int] = GlobalGameData.get_match_input_methods()
	player1_input_method_option_button.select(clampi(selected_methods[0], 0, labels.size() - 1))
	player2_input_method_option_button.select(clampi(selected_methods[1], 0, labels.size() - 1))


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


func _on_player_selected(index: int) -> void:
	if _players.size() > 1 and index == opponent_option_button.selected:
		opponent_option_button.select((index + 1) % _players.size())
	_refresh_view()


func _on_opponent_selected(index: int) -> void:
	if _players.size() > 1 and index == player_option_button.selected:
		player_option_button.select((index + 1) % _players.size())
	_refresh_view()


func _on_player1_input_method_selected(index: int) -> void:
	GlobalGameData.set_match_input_methods(index, player2_input_method_option_button.selected)


func _on_player2_input_method_selected(index: int) -> void:
	GlobalGameData.set_match_input_methods(player1_input_method_option_button.selected, index)


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
	return "#%s  %s %s\n%s  |  %scm  |  %sH" % [
		str(player_data.rank),
		player_data.first_name,
		player_data.last_name,
		player_data.country,
		str(player_data.height),
		player_data.hand,
	]


func _plot_stats(player_data: PlayerData, opponent_data: PlayerData) -> void:
	var x_values: Array = ["Serve", "Serve Acc", "Forehand", "Backhand", "Speed", "Agility", "Stamina", "Focus"]
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
	GlobalGameData.set_match_input_methods(
		player1_input_method_option_button.selected,
		player2_input_method_option_button.selected
	)
	GlobalGameData.set_match_players(player, opponent)
	selection_confirmed.emit()
