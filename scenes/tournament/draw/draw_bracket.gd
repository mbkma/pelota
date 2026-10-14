## The draw from one round on, like a tournament website shows it: the round's matches in a
## column, the following rounds' matches in the columns beside them, each match between the two
## matches its players come from, joined by bracket lines. The lines of the player's way through
## the draw are in `path_color`. After the final, the champion stands beside it.
class_name DrawBracket
extends Control

## A player line of a card was picked
signal player_picked(tournament_match: TournamentMatch, player: PlayerData)

@export var match_card_scene: PackedScene
@export var champion_card_scene: PackedScene
## Rounds shown side by side
@export var column_count: int = 3
@export var card_size: Vector2 = Vector2(380, 116)
@export var card_gap: float = 18.0
## Space between the columns, where the bracket lines run
@export var column_gap: float = 64.0
## Space left and right of the columns for the lines coming in and going on
@export var edge: float = 28.0
@export var line_width: float = 3.0
@export var line_color: Color = Palette.PURPLE
@export var path_color: Color = Palette.AMBER

var _tournament: Tournament
var _round_index: int = 0
## Cards per column; the last column after the final holds the champion's card
var _columns: Array[Array] = []
## The player lines of all cards; the pressed one is the picked player
var _line_group := ButtonGroup.new()


## Left edge of column `column` (0: the shown round).
func column_x(column: int) -> float:
	return edge + column * (card_size.x + column_gap)


## Shows `round_index` of `tournament` and the rounds after it, up to column_count rounds and
## the champion.
func show_round(tournament: Tournament, round_index: int) -> void:
	_tournament = tournament
	_round_index = round_index
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_columns.clear()
	var centers: Array[float] = []
	var first_round: Array = _round_or_tbd(round_index)
	for i in first_round.size():
		centers.append(i * (card_size.y + card_gap) + card_size.y / 2.0)
	for column in column_count:
		var column_round: int = round_index + column
		var cards: Array[Control] = []
		if column_round < tournament.round_count():
			var column_matches: Array = _round_or_tbd(column_round)
			for i in column_matches.size():
				cards.append(_add_card(column_matches[i], column, centers[i]))
		elif column_round == tournament.round_count() and tournament.is_over():
			var champion: ChampionCard = champion_card_scene.instantiate()
			add_child(champion)
			_place(champion, column, centers[0])
			champion.show_champion(tournament.champion())
			cards.append(champion)
		if cards.is_empty():
			break
		_columns.append(cards)
		var next_centers: Array[float] = []
		for j in range(0, centers.size() - 1, 2):
			next_centers.append((centers[j] + centers[j + 1]) / 2.0)
		# The final's winner goes straight on to the champion.
		centers = next_centers if not next_centers.is_empty() else centers
	custom_minimum_size = Vector2(
		column_x(_columns.size()) - column_gap + edge,
		first_round.size() * (card_size.y + card_gap) - card_gap + 8.0
	)
	queue_redraw()


## The card of `tournament_match` among the shown ones, null if it is not shown.
func card_of(tournament_match: TournamentMatch) -> MatchCard:
	for cards in _columns:
		for card in cards:
			if card is MatchCard and card.tournament_match == tournament_match:
				return card
	return null


## Presses the line of `player` in `tournament_match`, if shown; else none.
func set_selected(tournament_match: TournamentMatch, player: PlayerData) -> void:
	var pressed_line: BaseButton = _line_group.get_pressed_button()
	if pressed_line:
		pressed_line.set_pressed_no_signal(false)
	var card: MatchCard = card_of(tournament_match)
	if card and card.line_of(player):
		card.line_of(player).set_pressed_no_signal(true)


func _draw() -> void:
	if _columns.is_empty():
		return
	var half_height: float = card_size.y / 2.0
	# Lines coming in from the round before
	if _round_index > 0:
		for card: MatchCard in _columns[0]:
			var y: float = card.position.y + half_height
			draw_line(Vector2(0, y), Vector2(column_x(0), y), _color(card, false), line_width)
	for column in _columns.size():
		var join_x: float = column_x(column) + card_size.x + column_gap / 2.0
		var cards: Array = _columns[column]
		var next_cards: Array = _columns[column + 1] if column + 1 < _columns.size() else []
		for i in cards.size():
			if not cards[i] is MatchCard:
				continue
			var card: MatchCard = cards[i]
			var y: float = card.position.y + half_height
			var color: Color = _color(card, true)
			var right_edge: float = column_x(column) + card_size.x
			if next_cards.is_empty():
				# Going on to rounds not shown
				draw_line(Vector2(right_edge, y), Vector2(right_edge + edge, y), color, line_width)
				continue
			@warning_ignore("integer_division")
			var next_card: Control = next_cards[mini(i / 2, next_cards.size() - 1)]
			var target_y: float = next_card.position.y + half_height
			draw_line(Vector2(right_edge, y), Vector2(join_x, y), color, line_width)
			draw_line(Vector2(join_x, y), Vector2(join_x, target_y), color, line_width)
			if i % 2 == 0 or cards.size() == 1:
				var in_color: Color = color
				if next_card is MatchCard:
					in_color = _color(next_card, false)
				draw_line(
					Vector2(join_x - line_width / 2.0, target_y),
					Vector2(column_x(column + 1), target_y),
					in_color,
					line_width
				)


## path_color where the player's way through the draw runs into `card` (`outgoing` false) or
## on out of it, i.e. the player won it (`outgoing` true); else line_color.
func _color(card: MatchCard, outgoing: bool) -> Color:
	var card_match: TournamentMatch = card.tournament_match
	if card_match == null or not card_match.has_player(_tournament.player):
		return line_color
	if not outgoing:
		return path_color if card_match.round_index > 0 else line_color
	var won: bool = card_match.is_played() and card_match.get_winner() == _tournament.player
	return path_color if won else line_color


## The matches of `round_index`, or nulls (TBD) for a round not drawn yet.
func _round_or_tbd(round_index: int) -> Array:
	var round_matches: Array = _tournament.round_matches(round_index)
	if round_matches.is_empty():
		round_matches.resize(Tournament.DRAW_SIZE >> (round_index + 1))
	return round_matches


func _add_card(card_match: TournamentMatch, column: int, center_y: float) -> MatchCard:
	var card: MatchCard = match_card_scene.instantiate()
	add_child(card)
	_place(card, column, center_y)
	card.show_match(card_match, _tournament, _line_group)
	card.player_picked.connect(player_picked.emit)
	return card


func _place(card: Control, column: int, center_y: float) -> void:
	card.position = Vector2(column_x(column), center_y - card_size.y / 2.0)
	card.size = card_size
