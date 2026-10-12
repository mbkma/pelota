## Options tab of the UI settings (see UiSettings): the camera view and one toggle per UI element
## of the match.
class_name InterfaceOptionsMenu
extends MarginContainer

@onready var _controls: Dictionary[UiSettings.Element, OptionControl] = {
	UiSettings.Element.STROKE_INDICATOR: %StrokeIndicatorControl,
	UiSettings.Element.AIM_MARKER: %AimMarkerControl,
	UiSettings.Element.AI_AIM_MARKER: %AiAimMarkerControl,
	UiSettings.Element.POSITION_MARKER: %PositionMarkerControl,
	UiSettings.Element.SHOT_RATING: %ShotRatingControl,
	UiSettings.Element.SCORE_PANEL: %ScorePanelControl,
	UiSettings.Element.PLAYER_STATUS: %PlayerStatusControl,
	UiSettings.Element.AI_PLAYER_STATUS: %AiPlayerStatusControl,
}
@onready var _camera_view_control: ListOptionControl = %CameraViewControl


func _ready() -> void:
	for element in _controls:
		var control: OptionControl = _controls[element]
		control.value = UiSettings.is_shown(element)
		control.setting_changed.connect(_on_setting_changed.bind(element))
	_camera_view_control.value = UiSettings.get_camera_view()
	_camera_view_control.setting_changed.connect(UiSettings.set_camera_view)


func _on_setting_changed(shown: bool, element: UiSettings.Element) -> void:
	UiSettings.set_shown(element, shown)
