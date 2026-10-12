## Options tab of the UI settings (see UiSettings): one toggle per UI element of the match.
class_name InterfaceOptionsMenu
extends MarginContainer

@onready var _controls: Dictionary[UiSettings.Element, OptionControl] = {
	UiSettings.Element.STROKE_INDICATOR: %StrokeIndicatorControl,
	UiSettings.Element.AIM_MARKER: %AimMarkerControl,
	UiSettings.Element.POSITION_MARKER: %PositionMarkerControl,
	UiSettings.Element.SHOT_RATING: %ShotRatingControl,
	UiSettings.Element.SCORE_PANEL: %ScorePanelControl,
	UiSettings.Element.PLAYER_STATUS: %PlayerStatusControl,
}


func _ready() -> void:
	for element in _controls:
		var control: OptionControl = _controls[element]
		control.value = UiSettings.is_shown(element)
		control.setting_changed.connect(_on_setting_changed.bind(element))


func _on_setting_changed(shown: bool, element: UiSettings.Element) -> void:
	UiSettings.set_shown(element, shown)
