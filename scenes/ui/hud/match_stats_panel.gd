## Overlay with the match statistics of both players. Toggled with Tab or the gamepad's Back
## button; shown automatically after each set (with a Continue button that starts the next
## set) and when the match ends.
class_name MatchStatsPanel
extends Control

@export var match_manager: MatchManager

## Statistic rows, in the order of _stat_texts
const ROW_LABELS: Array[String] = [
	"Aces",
	"Double faults",
	"1st serve in",
	"1st serve points won",
	"2nd serve points won",
	"Fastest serve",
	"Avg. 1st serve speed",
	"Break points won",
	"Break points saved",
	"Winners",
	"Errors",
	"Net points won",
	"Total points won",
	"Distance covered",
]

## Value labels per row: [player0 label, player1 label]
var _value_labels: Array[Array] = []

@onready var _title_label: Label = %TitleLabel
@onready var _player1_label: Label = %Player1Label
@onready var _player2_label: Label = %Player2Label
@onready var _grid: GridContainer = %StatsGrid
@onready var _footer_label: Label = %FooterLabel
@onready var _hint_label: Label = %HintLabel
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	visible = false
	_player1_label.text = match_manager.player0.player_data.last_name
	_player2_label.text = match_manager.player1.player_data.last_name
	for row_label in ROW_LABELS:
		var values: Array[Label] = [_add_cell(""), _add_cell(row_label), _add_cell("")]
		values[1].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		values[1].modulate = Color(1, 1, 1, 0.7)
		_value_labels.append([values[0], values[2]])
	match_manager.match_finished.connect(_on_match_finished)
	match_manager.set_break_started.connect(_on_set_break_started)
	_continue_button.pressed.connect(_on_continue_pressed)


func _unhandled_input(event: InputEvent) -> void:
	var toggle_key: bool = (
		event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB
	)
	var toggle_button: bool = (
		event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK
	)
	if (toggle_key or toggle_button) and not _continue_button.visible:
		visible = not visible
		get_viewport().set_input_as_handled()
	elif visible and not _continue_button.visible and event.is_action_pressed(&"ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	var statistics: Array[MatchStatistics] = match_manager.match_data.statistics
	for player_index in 2:
		var texts: Array[String] = _stat_texts(statistics[player_index])
		for row in texts.size():
			_value_labels[row][player_index].text = texts[row]
	_footer_label.text = "Longest rally: %d shots" % match_manager.match_data.longest_rally


func _on_set_break_started(set_number: int) -> void:
	var games: Vector2i = match_manager.match_data.get_score().completed_sets[set_number - 1]
	var set_winner: Player = match_manager.player0 if games.x > games.y else match_manager.player1
	var winner_games: int = maxi(games.x, games.y)
	var loser_games: int = mini(games.x, games.y)
	_title_label.text = (
		"%s wins set %d  ·  %d-%d"
		% [set_winner.player_data.last_name, set_number, winner_games, loser_games]
	)
	_hint_label.visible = false
	_continue_button.visible = true
	visible = true
	_continue_button.grab_focus()


func _on_continue_pressed() -> void:
	_continue_button.visible = false
	_hint_label.visible = true
	_title_label.text = "Match Statistics"
	visible = false
	match_manager.continue_after_set_break()


func _on_match_finished(winner_index: int) -> void:
	var winner: Player = match_manager.player0 if winner_index == 0 else match_manager.player1
	_title_label.text = "%s wins the match" % winner.player_data.last_name
	visible = true


func _add_cell(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grid.add_child(label)
	return label


## Texts of one player's statistics, in the order of ROW_LABELS.
static func _stat_texts(s: MatchStatistics) -> Array[String]:
	return [
		str(s.aces),
		str(s.double_faults),
		_ratio(s.first_serves_in, s.first_serves_total),
		_ratio(s.first_serve_points_won, s.first_serve_points_played),
		_ratio(s.second_serve_points_won, s.second_serve_points_played),
		"%d km/h" % roundi(s.fastest_serve_kmh),
		"%d km/h" % roundi(s.average_first_serve_kmh()),
		_ratio(s.break_points_won, s.break_points_played),
		_ratio(s.break_points_saved, s.break_points_faced),
		str(s.winners),
		str(s.errors),
		_ratio(s.net_points_won, s.net_points_played),
		str(s.total_points_won),
		"%d m" % roundi(s.distance_covered),
	]


static func _ratio(part: int, total: int) -> String:
	if total == 0:
		return "-"
	return "%d/%d (%d%%)" % [part, total, roundi(100.0 * part / total)]
