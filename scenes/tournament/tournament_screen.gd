## The draw of the running tournament (GlobalGameData.tournament), laid out like a tournament
## website: the header with the tournament and the player's next match, the round buttons
## (R128 to F), the bracket of the shown round and the next one, and beside it the head to head
## and the profile of the picked player and the tournament's news. Below are the length of the
## player's matches and buttons to play or simulate the next match, to simulate the rest of the
## tournament once the player is out, and back to the main menu.
class_name TournamentScreen
extends Control

## Sets of the player's matches the player can choose
const BEST_OF_SETS_CHOICES: Array[int] = [3, 5]

@export_file("*.tscn") var match_scene_path: String
@export var news_item_scene: PackedScene
## Headlines shown in the news
@export var news_count: int = 8
## Opacity of the buttons of rounds not drawn yet
@export_range(0.0, 1.0) var undrawn_round_alpha: float = 0.55

var _tournament: Tournament
var _shown_round: int = 0
var _selected_match: TournamentMatch
var _selected_player: PlayerData

@onready var _badge_name_label: Label = %BadgeNameLabel
@onready var _badge_category_label: Label = %BadgeCategoryLabel
@onready var _state_badge: PanelContainer = %StateBadge
@onready var _state_label: Label = %StateLabel
@onready var _title_label: Label = %TitleLabel
@onready var _info_label: Label = %InfoLabel
@onready var _status_label: Label = %StatusLabel
@onready var _prev_round_button: Button = %PrevRoundButton
@onready var _next_round_button: Button = %NextRoundButton
@onready var _round_buttons: Array[Node] = %RoundButtons.get_children()
@onready var _my_match_button: Button = %MyMatchButton
## A label per column of the bracket with the column's round
@onready var _column_heads: Control = %ColumnHeads
@onready var _draw_scroll: ScrollContainer = %DrawScroll
@onready var _bracket: DrawBracket = %Bracket
@onready var _head_to_head: HeadToHeadCard = %HeadToHeadCard
@onready var _profile: PlayerProfileCard = %PlayerProfileCard
@onready var _no_news_label: Label = %NoNewsLabel
@onready var _news_list: VBoxContainer = %NewsList
@onready var _sets_option: OptionButton = %SetsOption
@onready var _play_button: Button = %PlayButton
@onready var _simulate_match_button: Button = %SimulateMatchButton
@onready var _simulate_button: Button = %SimulateButton
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	_tournament = GlobalGameData.tournament
	_badge_name_label.text = Tournament.NAME.to_upper()
	_badge_category_label.text = Tournament.CATEGORY.to_upper()
	_title_label.text = Tournament.NAME
	_info_label.text = (
		"%s  |  Men's Singles  |  %d players" % [Tournament.LOCATION, Tournament.DRAW_SIZE]
	)
	_draw_scroll.get_h_scroll_bar().value_changed.connect(_place_column_heads.unbind(1))
	_place_column_heads()
	for round_index in _round_buttons.size():
		var button: Button = _round_buttons[round_index]
		button.text = _tournament.round_short_name(round_index)
		button.tooltip_text = _tournament.round_name(round_index)
		button.pressed.connect(_show_round.bind(round_index))
	for sets in BEST_OF_SETS_CHOICES:
		_sets_option.add_item("Your matches: best of %d sets" % sets)
	_sets_option.select(BEST_OF_SETS_CHOICES.find(_tournament.best_of_sets))
	_sets_option.item_selected.connect(_on_sets_selected)
	_bracket.player_picked.connect(_select)
	_prev_round_button.pressed.connect(func() -> void: _show_round(_shown_round - 1))
	_next_round_button.pressed.connect(func() -> void: _show_round(_shown_round + 1))
	_my_match_button.pressed.connect(_on_my_match_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_simulate_match_button.pressed.connect(_on_simulate_match_pressed)
	_simulate_button.pressed.connect(_on_simulate_pressed)
	_main_menu_button.pressed.connect(SceneLoader.load_scene.bind(AppConfig.main_menu_scene_path))
	_refresh()


## The shoulder buttons and Page Up / Page Down switch between the rounds. Read in _input,
## before the focused control: an open dropdown list keeps them.
func _input(event: InputEvent) -> void:
	var step: int = UiPage.step(event)
	if step == 0:
		return
	_show_round(posmod(_shown_round + step, _tournament.round_count()))
	get_viewport().set_input_as_handled()


## Shows the state of the tournament, the round of the player's latest match with it picked,
## and the news.
func _refresh() -> void:
	var over: bool = _tournament.is_over()
	_state_label.text = "FINISHED" if over else "LIVE"
	_state_badge.theme_type_variation = &"BadgeTeal" if over else &"BadgeRed"
	_status_label.text = _status()
	var own_match: TournamentMatch = _tournament.player_match()
	_play_button.visible = own_match != null
	_simulate_match_button.visible = own_match != null
	_sets_option.visible = own_match != null
	_simulate_button.visible = own_match == null and not over
	for round_index in _round_buttons.size():
		_round_buttons[round_index].modulate.a = (
			1.0 if round_index <= _tournament.current_round else undrawn_round_alpha
		)
	_show_news()
	_show_my_match()
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
		return "Champion: %s" % champion.full_name()
	var own_match: TournamentMatch = _tournament.player_match()
	if own_match:
		return (
			"Next: %s against %s"
			% [
				_tournament.round_name(own_match.round_index),
				_entrant(own_match.opponent_of(_tournament.player)),
			]
		)
	var lost: TournamentMatch = _tournament.player_lost_match()
	return (
		"You lost to %s in the %s %s"
		% [_entrant(lost.get_winner()), _tournament.round_name(lost.round_index), lost.score]
	)


## The player's latest match: the next one, or the last one played.
func _my_match() -> TournamentMatch:
	return _tournament.matches_of(_tournament.player)[-1]


## Shows the round of the player's latest match with it picked and in view.
func _show_my_match() -> void:
	var own: TournamentMatch = _my_match()
	_show_round(own.round_index)
	_select(own, _tournament.player)
	_scroll_to(own)


func _show_round(round_index: int) -> void:
	_shown_round = clampi(round_index, 0, _tournament.round_count() - 1)
	_bracket.show_round(_tournament, _shown_round)
	_bracket.set_selected(_selected_match, _selected_player)
	for column in _column_heads.get_child_count():
		var head_round: int = _shown_round + column
		var head: Label = _column_heads.get_child(column)
		head.visible = head_round <= _tournament.round_count()
		if head_round < _tournament.round_count():
			head.text = _tournament.round_name(head_round)
		else:
			head.text = "Champion"
	_prev_round_button.disabled = _shown_round == 0
	_next_round_button.disabled = _shown_round == _tournament.round_count() - 1
	_round_buttons[_shown_round].button_pressed = true
	_draw_scroll.scroll_vertical = 0
	_draw_scroll.scroll_horizontal = 0


## Keeps the column heads over the bracket's columns as it scrolls sideways.
func _place_column_heads() -> void:
	for column in _column_heads.get_child_count():
		var head: Label = _column_heads.get_child(column)
		head.position.x = _bracket.column_x(column) - _draw_scroll.scroll_horizontal


## Picks `player` of `tournament_match`: shows the match's head to head and the player's profile.
func _select(tournament_match: TournamentMatch, player: PlayerData) -> void:
	if tournament_match != _selected_match:
		_head_to_head.show_match(tournament_match, _tournament)
	if player != _selected_player:
		_profile.show_player(player, _tournament)
	_selected_match = tournament_match
	_selected_player = player
	_bracket.set_selected(tournament_match, player)


## Scrolls the draw to the card of `tournament_match` once laid out.
func _scroll_to(tournament_match: TournamentMatch) -> void:
	await get_tree().process_frame
	var card: MatchCard = _bracket.card_of(tournament_match)
	if card:
		_draw_scroll.scroll_vertical = int(
			card.position.y - (_draw_scroll.size.y - card.size.y) / 2.0
		)


## The latest headlines; picking one shows its match.
func _show_news() -> void:
	for child in _news_list.get_children():
		child.queue_free()
	var headlines: Array[Dictionary] = TournamentNews.headlines(_tournament, news_count)
	_no_news_label.visible = headlines.is_empty()
	for headline in headlines:
		var item: NewsItem = news_item_scene.instantiate()
		_news_list.add_child(item)
		item.show_headline(headline, _tournament)
		item.picked.connect(_on_news_picked)


func _on_news_picked(news_match: TournamentMatch) -> void:
	_show_round(news_match.round_index)
	_select(news_match, news_match.get_winner())
	_scroll_to(news_match)


## Name of a player in the draw, with the seed: "(1) Jannik Sinner".
func _entrant(entrant: PlayerData) -> String:
	var seed_number: int = _tournament.seed_of(entrant)
	var seed_text: String = "(%d) " % seed_number if seed_number > 0 else ""
	return seed_text + entrant.full_name()


func _on_my_match_pressed() -> void:
	_show_my_match()
	var card: MatchCard = _bracket.card_of(_my_match())
	card.line_of(_tournament.player).grab_focus()


func _on_sets_selected(index: int) -> void:
	_tournament.best_of_sets = BEST_OF_SETS_CHOICES[index]
	_tournament.save()
	# The win chances of the player's match depend on its length.
	_selected_match = null
	_select(_my_match(), _selected_player)


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
