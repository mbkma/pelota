## The UI settings: which of the match's UI elements are shown. By default the human player's
## stroke indicator, the aim marker and the score panel are; the others are turned on in the
## options. The settings are kept in the player config (see PlayerConfig), and the elements show
## or hide at once when one changes (see changed).
extends Node

signal changed

enum Element {
	## Circle above a human player's head while the stroke button can be used (see
	## StrokeIndicator)
	STROKE_INDICATOR,
	## Where the aimed shot may land
	AIM_MARKER,
	## Where to stand to meet the incoming ball
	POSITION_MARKER,
	## Rating of a human player's shot ("PERFECT!") above the player
	SHOT_RATING,
	## The TV score panel with its captions and statistics
	SCORE_PANEL,
	## Stamina, pressure and confidence of the players
	PLAYER_STATUS,
}

const SECTION: StringName = AppSettings.GAME_SECTION
## Config key of each element
const KEYS: Dictionary[Element, StringName] = {
	Element.STROKE_INDICATOR: &"ShowStrokeIndicator",
	Element.AIM_MARKER: &"ShowAimMarker",
	Element.POSITION_MARKER: &"ShowPositionMarker",
	Element.SHOT_RATING: &"ShowShotRating",
	Element.SCORE_PANEL: &"ShowScorePanel",
	Element.PLAYER_STATUS: &"ShowPlayerStatus",
}
const SHOWN_BY_DEFAULT: Array[Element] = [
	Element.STROKE_INDICATOR, Element.AIM_MARKER, Element.SCORE_PANEL
]


func is_shown(element: Element) -> bool:
	return PlayerConfig.get_config(SECTION, KEYS[element], is_shown_by_default(element))


func is_shown_by_default(element: Element) -> bool:
	return SHOWN_BY_DEFAULT.has(element)


func set_shown(element: Element, shown: bool) -> void:
	PlayerConfig.set_config(SECTION, KEYS[element], shown)
	changed.emit()
