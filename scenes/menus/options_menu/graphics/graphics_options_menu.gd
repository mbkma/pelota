## Options tab of the graphics settings (see GraphicsSettings): a quality preset and every setting
## on its own. Choosing a preset shows its settings; changing a setting shows the preset the
## settings now match, or custom.
class_name GraphicsOptionsMenu
extends MarginContainer

@onready var _preset_control: ListOptionControl = %PresetControl
@onready var _setting_controls: Array[OptionControl] = [
	%RenderScaleControl,
	%MsaaControl,
	%ScreenSpaceAaControl,
	%ShadowsControl,
	%AmbientOcclusionControl,
	%GlowControl,
	%MeshDetailControl,
	%TextureFilteringControl,
	%CrowdDetailControl,
	%MaxFpsControl,
]


func _ready() -> void:
	# Custom is shown, not chosen: it is what changing a single setting leads to.
	_preset_control.disable_option(GraphicsSettings.Preset.CUSTOM)
	_preset_control.setting_changed.connect(_on_preset_selected)
	for control in _setting_controls:
		control.setting_changed.connect(_on_setting_changed.bind(control.key))
	_show_settings()


func _on_preset_selected(preset: int) -> void:
	GraphicsSettings.select_preset(preset)
	_show_settings()


func _on_setting_changed(value: Variant, key: String) -> void:
	GraphicsSettings.set_value(key, value)
	_preset_control.value = GraphicsSettings.get_preset()


func _show_settings() -> void:
	_preset_control.value = GraphicsSettings.get_preset()
	for control in _setting_controls:
		control.value = GraphicsSettings.get_value(control.key)
