## One player of a match card: avatar, flag, short name, seed, a check mark for the winner and
## the games of each set; TBD for a player not yet known. A toggle button: pressed while it is
## the picked player of the draw.
class_name DrawPlayerLine
extends Button

## Emitted when the line is focused or pressed
signal picked

## Opacity of the name of the player who lost
@export_range(0.0, 1.0) var loser_alpha: float = 0.6
@export var set_score_scene: PackedScene

@onready var _avatar: PlayerAvatar = %PlayerAvatar
@onready var _flag: CountryFlag = %CountryFlag
@onready var _name_label: Label = %NameLabel
@onready var _seed_label: Label = %SeedLabel
@onready var _check: TextureRect = %Check
@onready var _sets: HBoxContainer = %Sets


func _ready() -> void:
	focus_entered.connect(picked.emit)
	pressed.connect(picked.emit)


## Shows player `index` of `tournament_match` (null: not drawn yet) in `tournament`.
func show_player(tournament_match: TournamentMatch, index: int, tournament: Tournament) -> void:
	var player: PlayerData = tournament_match.players[index] if tournament_match else null
	_avatar.show_player(player)
	_flag.visible = player != null
	_seed_label.visible = false
	_check.visible = false
	disabled = player == null
	focus_mode = Control.FOCUS_NONE if player == null else Control.FOCUS_ALL
	if player == null:
		_name_label.text = "TBD"
		_name_label.modulate.a = loser_alpha
		return
	_flag.country_code = player.country_code
	_name_label.text = player.short_name()
	var seed_number: int = tournament.seed_of(player)
	_seed_label.visible = seed_number > 0
	_seed_label.text = "(%d)" % seed_number
	var played: bool = tournament_match.is_played()
	var won: bool = played and tournament_match.winner == index
	_check.visible = won
	_name_label.theme_type_variation = &"BoldLabel" if won else &""
	if player == tournament.player:
		_name_label.add_theme_color_override(&"font_color", Palette.PLAYER_1)
	_name_label.modulate.a = loser_alpha if played and not won else 1.0
	for set_index in tournament_match.set_games.size():
		var games: Vector2i = tournament_match.set_games[set_index]
		var set_won: bool = games[index] > games[1 - index]
		var set_score: SetScore = set_score_scene.instantiate()
		_sets.add_child(set_score)
		set_score.show_games(
			games[index],
			-1 if set_won else tournament_match.tiebreak_loser_points(set_index),
			set_won
		)
