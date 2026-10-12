## The UI settings: which of the match's UI elements are shown, and the camera view the match is
## watched from. By default all elements are shown, except the aim marker and the status panel of
## the AI players, which are turned on in the options. The camera view is set in the options and
## in the pause menu. The settings are kept in the player config (see PlayerConfig) and apply at
## once when one changes (see changed).
extends Node

signal changed

enum Element {
	## Circle above a human player's head while the stroke button can be used (see
	## StrokeIndicator)
	STROKE_INDICATOR,
	## Where a human player's aimed shot may land
	AIM_MARKER,
	## Where an AI player's shot is aimed
	AI_AIM_MARKER,
	## Where to stand to meet the incoming ball
	POSITION_MARKER,
	## Rating of a human player's shot ("PERFECT!") above the player
	SHOT_RATING,
	## The TV score panel with its captions and statistics
	SCORE_PANEL,
	## Stamina, pressure and confidence of a human player
	PLAYER_STATUS,
	## Stamina, pressure and confidence of an AI player
	AI_PLAYER_STATUS,
}

## Camera views a match is watched from (see MatchCameras)
enum CameraView {
	## High behind the baseline, like a TV broadcast
	BROADCAST,
	## Lower and closer behind the baseline
	ELEVATED,
	## From the side of the court
	COURTSIDE,
	## From straight above
	OVERHEAD,
	## Through the eyes of the player
	PLAYER,
}

const SECTION: StringName = AppSettings.GAME_SECTION
const CAMERA_VIEW_KEY: StringName = &"CameraView"
## Config key of each element
const KEYS: Dictionary[Element, StringName] = {
	Element.STROKE_INDICATOR: &"ShowStrokeIndicator",
	Element.AIM_MARKER: &"ShowAimMarker",
	Element.AI_AIM_MARKER: &"ShowAiAimMarker",
	Element.POSITION_MARKER: &"ShowPositionMarker",
	Element.SHOT_RATING: &"ShowShotRating",
	Element.SCORE_PANEL: &"ShowScorePanel",
	Element.PLAYER_STATUS: &"ShowPlayerStatus",
	Element.AI_PLAYER_STATUS: &"ShowAiPlayerStatus",
}
const HIDDEN_BY_DEFAULT: Array[Element] = [Element.AI_AIM_MARKER, Element.AI_PLAYER_STATUS]


func is_shown(element: Element) -> bool:
	return PlayerConfig.get_config(SECTION, KEYS[element], is_shown_by_default(element))


func is_shown_by_default(element: Element) -> bool:
	return not HIDDEN_BY_DEFAULT.has(element)


func set_shown(element: Element, shown: bool) -> void:
	PlayerConfig.set_config(SECTION, KEYS[element], shown)
	changed.emit()


func get_camera_view() -> CameraView:
	return PlayerConfig.get_config(SECTION, CAMERA_VIEW_KEY, CameraView.BROADCAST)


func set_camera_view(view: CameraView) -> void:
	PlayerConfig.set_config(SECTION, CAMERA_VIEW_KEY, view)
	changed.emit()
