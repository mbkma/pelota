## TV graphics of the match, directed like the US Open's broadcast: the score panel, and after a
## point now and then extra information on it:
## - a caption for the coming point: championship, set or break point, or deuce, counted within
##   the game ("BREAK POINT #2"), and championship points within the match;
## - when nothing is at stake, sometimes an IBM statistic (break points won, first serves,
##   aces, winners, the last ten points);
## - the stadium's name when the broadcast starts.
## Shown when turned on in the UI settings.
class_name TelevisionHud
extends Control

## Seconds a caption and a statistic are shown
const CAPTION_SECONDS: float = 6.0
const STATISTIC_SECONDS: float = 6.0
## Chance after a point to show a statistic, and points at least between two statistics
const STATISTIC_CHANCE: float = 0.3
const POINTS_BETWEEN_STATISTICS: int = 4
## Points the "last points" statistic looks back on
const RECENT_POINTS: int = 10
const VENUE: String = "ARTHUR ASHE STADIUM"

## Counts within the current game, and of championship points within the match
var _game: int = -1
var _break_points: int = 0
var _set_points: int = 0
var _deuces: int = 0
var _championship_points: int = 0
## Winners of the last points, and points since the last statistic
var _recent_winners: Array[int] = []
var _points_since_statistic: int = 0

@onready var _score_display: ScoreDisplay = $ScoreDisplay


func _ready() -> void:
	UiSettings.changed.connect(_apply_ui_settings)
	_apply_ui_settings()


func _apply_ui_settings() -> void:
	visible = UiSettings.is_shown(UiSettings.Element.SCORE_PANEL)


func set_player(player_index: int, player_data: PlayerData) -> void:
	_score_display.set_player(player_index, player_data)


## Brings the score panel in and names the stadium.
func start_broadcast(score: Score) -> void:
	_score_display.set_score(score)
	_score_display.play_intro()
	await get_tree().create_timer(ScoreDisplay.INTRO_TIME).timeout
	_score_display.show_caption(VENUE, CAPTION_SECONDS)


## Shows the score after a point won by `winner`, and maybe a caption or a statistic.
func on_point_played(match_data: MatchData, winner: int) -> void:
	var score: Score = match_data.score
	_score_display.set_score(score)
	_recent_winners.append(winner)
	if _recent_winners.size() > RECENT_POINTS:
		_recent_winners.pop_front()
	_points_since_statistic += 1
	if score.is_match_over():
		return
	if score.games_played != _game:
		_game = score.games_played
		_break_points = 0
		_set_points = 0
		_deuces = 0
	var caption: String = _caption(score)
	if not caption.is_empty():
		_score_display.show_caption(caption, CAPTION_SECONDS)
	elif _points_since_statistic >= POINTS_BETWEEN_STATISTICS and randf() < STATISTIC_CHANCE:
		_show_statistic(match_data)


## The caption for the coming point, counting it ("" for none).
func _caption(score: Score) -> String:
	var server: int = score.current_server
	var importance: Array[Score.PointImportance] = [
		score.point_importance(server), score.point_importance(1 - server)
	]
	if importance.has(Score.PointImportance.MATCH):
		_championship_points += 1
		return _counted("CHAMPIONSHIP POINT", _championship_points)
	if importance.has(Score.PointImportance.SET):
		_set_points += 1
		return _counted("SET POINT", _set_points)
	if importance[1] == Score.PointImportance.BREAK:
		_break_points += 1
		return _counted("BREAK POINT", _break_points)
	if (
		not score.is_tiebreak
		and score.points[0] == Score.TennisPoint.FORTY
		and score.points[1] == Score.TennisPoint.FORTY
	):
		_deuces += 1
		return _counted("DEUCE", _deuces)
	return ""


func _counted(caption: String, count: int) -> String:
	return caption if count == 1 else "%s #%d" % [caption, count]


## Shows one of the statistics that has something to show.
func _show_statistic(match_data: MatchData) -> void:
	var stats: Array[MatchStatistics] = match_data.statistics
	var choices: Array[Array] = []
	if stats[0].break_points_played + stats[1].break_points_played > 0:
		choices.append(
			[
				"BREAK POINTS WON",
				_ratios(
					stats[0].break_points_won,
					stats[0].break_points_played,
					stats[1].break_points_won,
					stats[1].break_points_played
				)
			]
		)
	if stats[0].first_serves_total > 0 and stats[1].first_serves_total > 0:
		choices.append(
			[
				"1ST SERVE IN",
				_ratios(
					stats[0].first_serves_in,
					stats[0].first_serves_total,
					stats[1].first_serves_in,
					stats[1].first_serves_total
				)
			]
		)
	if stats[0].first_serve_points_played > 0 and stats[1].first_serve_points_played > 0:
		choices.append(
			[
				"1ST SERVE POINTS WON",
				_ratios(
					stats[0].first_serve_points_won,
					stats[0].first_serve_points_played,
					stats[1].first_serve_points_won,
					stats[1].first_serve_points_played
				)
			]
		)
	if stats[0].aces + stats[1].aces > 0:
		choices.append(["ACES", _counts(stats[0].aces, stats[1].aces)])
	if stats[0].winners + stats[1].winners > 0:
		choices.append(["WINNERS", _counts(stats[0].winners, stats[1].winners)])
	if _recent_winners.size() == RECENT_POINTS:
		choices.append(
			[
				"LAST %d POINTS" % RECENT_POINTS,
				_counts(_recent_winners.count(0), _recent_winners.count(1))
			]
		)
	if choices.is_empty():
		return
	var choice: Array = choices.pick_random()
	_score_display.show_statistic(choice[0], choice[1], STATISTIC_SECONDS)
	_points_since_statistic = 0


## Per player "won/played" and the percentage.
func _ratios(won0: int, played0: int, won1: int, played1: int) -> Array[PackedStringArray]:
	return [
		PackedStringArray(["%d/%d" % [won0, played0], _percent(won0, played0)]),
		PackedStringArray(["%d/%d" % [won1, played1], _percent(won1, played1)]),
	]


func _counts(count0: int, count1: int) -> Array[PackedStringArray]:
	return [PackedStringArray([str(count0), ""]), PackedStringArray([str(count1), ""])]


func _percent(won: int, played: int) -> String:
	return "%d%%" % roundi(100.0 * won / played) if played > 0 else "0%"
