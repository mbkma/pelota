## The games of one player in one set of a match card; a lost tiebreak's points as a small
## number at the top right.
class_name SetScore
extends Control

## Opacity of the games of a lost set
@export_range(0.0, 1.0) var lost_alpha: float = 0.6

@onready var _games_label: Label = %GamesLabel
@onready var _tiebreak_label: Label = %TiebreakLabel


## `tiebreak_points` -1 for none.
func show_games(games: int, tiebreak_points: int, won: bool) -> void:
	_games_label.text = str(games)
	_games_label.theme_type_variation = &"BoldLabel" if won else &""
	_games_label.modulate.a = 1.0 if won else lost_alpha
	_tiebreak_label.visible = tiebreak_points >= 0
	_tiebreak_label.text = str(tiebreak_points)
