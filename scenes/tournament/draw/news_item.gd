## A headline of the tournament news (see TournamentNews): the round on a badge colored by the
## kind of story, and the text. Pressing it emits `picked` with the match of the story.
class_name NewsItem
extends MarginContainer

signal picked(news_match: TournamentMatch)

var _match: TournamentMatch


func _ready() -> void:
	%Button.pressed.connect(func() -> void: picked.emit(_match))


func show_headline(headline: Dictionary, tournament: Tournament) -> void:
	_match = headline["match"]
	var kind: TournamentNews.Kind = headline["kind"]
	%Badge.theme_type_variation = TournamentNews.KIND_BADGES[kind]
	%RoundLabel.text = tournament.round_short_name(_match.round_index)
	%RoundLabel.theme_type_variation = (
		&"InkLabel" if kind == TournamentNews.Kind.CHAMPION else &"BoldLabel"
	)
	%TextLabel.text = headline["text"]
