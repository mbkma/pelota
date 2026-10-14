## The profile of a player of the draw: name, country, ranking, seed, age, height and hand, how
## far they got in the tournament, and their way through the draw match by match.
class_name PlayerProfileCard
extends PanelContainer

@export var path_row_scene: PackedScene

@onready var _avatar: PlayerAvatar = %PlayerAvatar
@onready var _first_name_label: Label = %FirstNameLabel
@onready var _last_name_label: Label = %LastNameLabel
@onready var _flag: CountryFlag = %CountryFlag
@onready var _country_label: Label = %CountryLabel
@onready var _ranking_label: Label = %RankingLabel
@onready var _seed_label: Label = %SeedLabel
@onready var _age_label: Label = %AgeLabel
@onready var _height_label: Label = %HeightLabel
@onready var _plays_label: Label = %PlaysLabel
@onready var _standing_title_label: Label = %StandingTitleLabel
@onready var _standing_label: Label = %StandingLabel
@onready var _path_rows: VBoxContainer = %PathRows


func show_player(player: PlayerData, tournament: Tournament) -> void:
	_avatar.show_player(player)
	_first_name_label.text = player.first_name.to_upper()
	_last_name_label.text = player.last_name.to_upper()
	if player == tournament.player:
		_last_name_label.add_theme_color_override(&"font_color", Palette.PLAYER_1)
	else:
		_last_name_label.remove_theme_color_override(&"font_color")
	_flag.country_code = player.country_code
	_country_label.text = player.country
	var seed_number: int = tournament.seed_of(player)
	_ranking_label.text = "#%d" % player.rank if player.rank > 0 else "-"
	_seed_label.text = str(seed_number) if seed_number > 0 else "-"
	_age_label.text = str(player.age)
	_height_label.text = "%d cm" % player.height
	_plays_label.text = (
		"%s-handed, %s backhand"
		% [
			"Left" if player.hand == "L" else "Right",
			"one-handed" if player.backhand == 1 else "two-handed",
		]
	)
	_standing_title_label.text = Tournament.NAME
	_standing_label.text = _standing(player, tournament)
	for row in _path_rows.get_children():
		row.queue_free()
	for player_match in tournament.matches_of(player):
		var row: PathRow = path_row_scene.instantiate()
		_path_rows.add_child(row)
		row.show_match(player, player_match, tournament)


## How far `player` got: "Champion (7-0)", "Out in the QF (4-1)", "Into the R16 (3-0)".
static func _standing(player: PlayerData, tournament: Tournament) -> String:
	var record: Vector2i = tournament.win_loss(player)
	var last_round: String = tournament.round_short_name(
		tournament.matches_of(player)[-1].round_index
	)
	var text: String = "Into the %s" % last_round
	if tournament.is_over() and tournament.champion() == player:
		text = "Champion"
	elif record.y > 0:
		text = "Out in the %s" % last_round
	return "%s  (%d-%d)" % [text, record.x, record.y]
