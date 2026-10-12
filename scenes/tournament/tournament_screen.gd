## The draw of the running tournament (GlobalGameData.tournament): its matches round by round with
## their results, the player's next match, the length of the player's matches, and buttons to
## play or simulate the next match, to simulate the rest of the tournament once the player is
## out, and back to the main menu.
class_name TournamentScreen
extends Control

## Sets of the player's matches the player can choose
const BEST_OF_SETS_CHOICES: Array[int] = [3, 5]

@export_file("*.tscn") var match_scene_path: String

var _tournament: Tournament

@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _round_tabs: TabBar = %RoundTabs
@onready var _match_list: VBoxContainer = %MatchList
@onready var _sets_option: OptionButton = %SetsOption
@onready var _play_button: Button = %PlayButton
@onready var _simulate_match_button: Button = %SimulateMatchButton
@onready var _simulate_button: Button = %SimulateButton
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	_tournament = GlobalGameData.tournament
	_title_label.text = "%s  ·  Men's Singles" % Tournament.NAME
	for round_index in _tournament.round_count():
		_round_tabs.add_tab(_tournament.round_name(round_index))
	for sets in BEST_OF_SETS_CHOICES:
		_sets_option.add_item("Your matches: best of %d sets" % sets)
	_sets_option.select(BEST_OF_SETS_CHOICES.find(_tournament.best_of_sets))
	_sets_option.item_selected.connect(_on_sets_selected)
	_round_tabs.tab_changed.connect(_show_round)
	_play_button.pressed.connect(_on_play_pressed)
	_simulate_match_button.pressed.connect(_on_simulate_match_pressed)
	_simulate_button.pressed.connect(_on_simulate_pressed)
	_main_menu_button.pressed.connect(SceneLoader.load_scene.bind(AppConfig.main_menu_scene_path))
	_refresh()


## The shoulder buttons and Page Up / Page Down switch between the rounds played so far. Read in
## _input, before the focused control: an open dropdown list keeps them.
func _input(event: InputEvent) -> void:
	var step: int = UiPage.step(event)
	if step == 0:
		return
	_round_tabs.current_tab = UiPage.next_tab(
		_round_tabs.current_tab, step, _round_tabs.tab_count, _round_tabs.is_tab_disabled
	)
	get_viewport().set_input_as_handled()


## Shows the state of the tournament and the current round.
func _refresh() -> void:
	for round_index in _tournament.round_count():
		_round_tabs.set_tab_disabled(round_index, round_index > _tournament.current_round)
	_round_tabs.current_tab = _tournament.current_round
	_show_round(_tournament.current_round)
	_status_label.text = _status()
	var own_match: TournamentMatch = _tournament.player_match()
	_play_button.visible = own_match != null
	_simulate_match_button.visible = own_match != null
	_sets_option.visible = own_match != null
	_simulate_button.visible = own_match == null and not _tournament.is_over()
	if own_match:
		_play_button.text = "Play the %s" % _tournament.round_name(_tournament.current_round)
		_play_button.grab_focus()
	elif _simulate_button.visible:
		_simulate_button.grab_focus()
	else:
		_main_menu_button.grab_focus()


func _status() -> String:
	if _tournament.is_over():
		var champion: PlayerData = _tournament.champion()
		if champion == _tournament.player:
			return "You are the %s champion!" % Tournament.NAME
		return "Champion: %s" % _full_name(champion)
	var own_match: TournamentMatch = _tournament.player_match()
	if own_match:
		return (
			"%s: %s against %s"
			% [
				_tournament.round_name(own_match.round_index),
				_full_name(_tournament.player),
				_entrant(_opponent(own_match)),
			]
		)
	var lost: TournamentMatch = _tournament.player_lost_match()
	return (
		"%s lost to %s in the %s %s"
		% [
			_full_name(_tournament.player),
			_full_name(lost.get_winner()),
			_tournament.round_name(lost.round_index),
			lost.score,
		]
	)


func _show_round(round_index: int) -> void:
	for row in _match_list.get_children():
		row.queue_free()
	for tournament_match in _tournament.round_matches(round_index):
		_match_list.add_child(_match_row(tournament_match))


## A row of the draw: both players (the winner highlighted, the player's own name in the player's
## color) and the score.
func _match_row(tournament_match: TournamentMatch) -> HBoxContainer:
	var row := HBoxContainer.new()
	for i in 2:
		var entrant: PlayerData = tournament_match.players[i]
		var label := Label.new()
		label.text = _entrant(entrant)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_stretch_ratio = 3.0
		label.clip_text = true
		if entrant == _tournament.player:
			label.add_theme_color_override("font_color", Palette.PLAYER_1)
		elif tournament_match.is_played() and tournament_match.winner == i:
			label.add_theme_color_override("font_color", Palette.AMBER)
		if tournament_match.is_played() and tournament_match.winner != i:
			label.modulate.a = 0.55
		row.add_child(label)
		if i == 0:
			var versus := Label.new()
			versus.text = "vs"
			versus.modulate.a = 0.6
			row.add_child(versus)
	var score := Label.new()
	score.text = tournament_match.score
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score.size_flags_stretch_ratio = 2.0
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score)
	return row


## Name of a player in the draw, with the seed and the country: "(1) Jannik Sinner ITA".
func _entrant(entrant: PlayerData) -> String:
	var seed_number: int = _tournament.seed_of(entrant)
	var seed_text: String = "(%d) " % seed_number if seed_number > 0 else ""
	return "%s%s %s" % [seed_text, _full_name(entrant), entrant.country_code]


func _full_name(player: PlayerData) -> String:
	return "%s %s" % [player.first_name, player.last_name]


func _opponent(tournament_match: TournamentMatch) -> PlayerData:
	return tournament_match.players[1 - tournament_match.players.find(_tournament.player)]


func _on_sets_selected(index: int) -> void:
	_tournament.best_of_sets = BEST_OF_SETS_CHOICES[index]
	_tournament.save()


func _on_play_pressed() -> void:
	GlobalGameData.prepare_tournament_match()
	SceneLoader.load_scene(match_scene_path)


func _on_simulate_match_pressed() -> void:
	_tournament.simulate_player_match()
	_tournament.save()
	_refresh()


func _on_simulate_pressed() -> void:
	_tournament.finish()
	_tournament.save()
	_refresh()
