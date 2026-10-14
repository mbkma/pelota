## The head to head of a match of the draw: both players with their chance to win the match
## (from simulated matches, see MatchSimulator) on a ring between them, the result once played,
## and the tale of the tape: ranking, age, height, hand, tournament record and how they serve,
## return and rally.
class_name HeadToHeadCard
extends PanelContainer

## Win chance of the first of two players per pairing and number of sets, computed once
static var _win_chances: Dictionary = {}

## Simulated matches behind a win chance
@export var win_chance_runs: int = 300

@onready var _round_label: Label = %RoundLabel
@onready var _avatars: Array[PlayerAvatar] = [%LeftAvatar, %RightAvatar]
@onready var _percent_labels: Array[Label] = [%LeftPercentLabel, %RightPercentLabel]
@onready var _ring: TextureProgressBar = %Ring
@onready var _first_name_labels: Array[Label] = [%LeftFirstNameLabel, %RightFirstNameLabel]
@onready var _last_name_labels: Array[Label] = [%LeftLastNameLabel, %RightLastNameLabel]
@onready var _flags: Array[CountryFlag] = [%LeftFlag, %RightFlag]
@onready var _code_labels: Array[Label] = [%LeftCodeLabel, %RightCodeLabel]
@onready var _caption_label: Label = %CaptionLabel
@onready var _ranking_row: TapeRow = %RankingRow
@onready var _age_row: TapeRow = %AgeRow
@onready var _height_row: TapeRow = %HeightRow
@onready var _plays_row: TapeRow = %PlaysRow
@onready var _tournament_row: TapeRow = %TournamentRow
@onready var _serve_row: RatingRow = %ServeRow
@onready var _return_row: RatingRow = %ReturnRow
@onready var _rally_row: RatingRow = %RallyRow


## Shows `tournament_match` of `tournament`.
func show_match(tournament_match: TournamentMatch, tournament: Tournament) -> void:
	var players: Array[PlayerData] = tournament_match.players
	_round_label.text = tournament.round_name(tournament_match.round_index)
	var best_of: int = (
		tournament.best_of_sets
		if tournament_match.has_player(tournament.player)
		else Tournament.SIMULATED_BEST_OF_SETS
	)
	var chance: float = _win_chance(players[0], players[1], best_of)
	_ring.value = chance
	_percent_labels[0].text = "%d%%" % roundi(chance * 100.0)
	_percent_labels[1].text = "%d%%" % (100 - roundi(chance * 100.0))
	for i in 2:
		_avatars[i].show_player(players[i])
		_first_name_labels[i].text = players[i].first_name
		_last_name_labels[i].text = players[i].last_name
		_flags[i].country_code = players[i].country_code
		_code_labels[i].text = players[i].country_code
	if tournament_match.is_played():
		_caption_label.text = (
			"%s won %s" % [tournament_match.get_winner().short_name(), tournament_match.score]
		)
	else:
		_caption_label.text = "Win chance  ·  best of %d sets" % best_of
	_ranking_row.show_values(_ranking(players[0]), _ranking(players[1]))
	_age_row.show_values(str(players[0].age), str(players[1].age))
	_height_row.show_values("%d cm" % players[0].height, "%d cm" % players[1].height)
	_plays_row.show_values(_hand(players[0]), _hand(players[1]))
	_tournament_row.show_values(
		_win_loss(tournament.win_loss(players[0])), _win_loss(tournament.win_loss(players[1]))
	)
	var stats: Array[PlayerStatsProfile] = [players[0].stats, players[1].stats]
	_serve_row.show_ratings(
		MatchSimulator.serve_rating(stats[0]), MatchSimulator.serve_rating(stats[1])
	)
	_return_row.show_ratings(
		MatchSimulator.return_rating(stats[0]), MatchSimulator.return_rating(stats[1])
	)
	_rally_row.show_ratings(
		MatchSimulator.baseline_rating(stats[0]), MatchSimulator.baseline_rating(stats[1])
	)


## Chance that `player` beats `opponent` over `best_of_sets`, simulated once per pairing.
func _win_chance(player: PlayerData, opponent: PlayerData, best_of_sets: int) -> float:
	var key: Array = [player, opponent, best_of_sets]
	if not _win_chances.has(key):
		_win_chances[key] = MatchSimulator.win_chance(
			player, opponent, best_of_sets, win_chance_runs
		)
	return _win_chances[key]


static func _ranking(player: PlayerData) -> String:
	return "#%d" % player.rank if player.rank > 0 else "-"


static func _hand(player: PlayerData) -> String:
	return "Left" if player.hand == "L" else "Right"


static func _win_loss(record: Vector2i) -> String:
	return "%d-%d" % [record.x, record.y]
