## A match of the draw as a card: a DrawPlayerLine per player. The player's own match has an
## amber border (theme type DrawCardOwn).
class_name MatchCard
extends PanelContainer

## A player line was picked: `player` of `tournament_match`
signal player_picked(tournament_match: TournamentMatch, player: PlayerData)

## The match shown; null for a match not drawn yet (both players TBD)
var tournament_match: TournamentMatch

@onready var _lines: Array[DrawPlayerLine] = [%TopLine, %BottomLine]


## Shows `card_match` (null: not drawn yet) of `tournament`; the lines join `line_group`, in
## which one line of the draw is pressed: the picked player.
func show_match(
	card_match: TournamentMatch, tournament: Tournament, line_group: ButtonGroup
) -> void:
	tournament_match = card_match
	var own: bool = card_match != null and card_match.has_player(tournament.player)
	theme_type_variation = &"DrawCardOwn" if own else &"DrawCard"
	for i in 2:
		_lines[i].show_player(card_match, i, tournament)
		_lines[i].button_group = line_group
		if card_match:
			_lines[i].picked.connect(player_picked.emit.bind(card_match, card_match.players[i]))


## The line of `player`, null if not in this match.
func line_of(player: PlayerData) -> DrawPlayerLine:
	if tournament_match == null or not tournament_match.has_player(player):
		return null
	return _lines[tournament_match.players.find(player)]
