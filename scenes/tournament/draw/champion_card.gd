## The champion beside the final on the draw.
class_name ChampionCard
extends PanelContainer

@onready var _avatar: PlayerAvatar = %PlayerAvatar
@onready var _title_label: Label = %TitleLabel
@onready var _name_label: Label = %NameLabel
@onready var _flag: CountryFlag = %CountryFlag
@onready var _country_label: Label = %CountryLabel


func show_champion(champion: PlayerData) -> void:
	_avatar.show_player(champion)
	_title_label.text = "%s CHAMPION" % Tournament.NAME.to_upper()
	_name_label.text = champion.full_name()
	_flag.country_code = champion.country_code
	_country_label.text = champion.country
