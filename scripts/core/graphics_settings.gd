## The graphics settings. A quality preset (low, medium, high or ultra) sets all of them at once;
## changing one on its own makes the preset custom. They are kept in the player config (see
## PlayerConfig) and applied to the renderer and every viewport, and to the lights, environments
## and crowds of the scenes as they enter the tree, so changes show at once, also during a match.
extends Node

enum Preset { LOW, MEDIUM, HIGH, ULTRA, CUSTOM }
enum Shadows { OFF, LOW, MEDIUM, HIGH, ULTRA }
enum AmbientOcclusion { OFF, LOW, MEDIUM, HIGH }

const SECTION: StringName = AppSettings.VIDEO_SECTION
const PRESET: StringName = &"GraphicsPreset"
const RENDER_SCALE: StringName = &"RenderScale"
const MSAA: StringName = &"Msaa"
const SCREEN_SPACE_AA: StringName = &"ScreenSpaceAa"
const SHADOWS: StringName = &"Shadows"
const AMBIENT_OCCLUSION: StringName = &"AmbientOcclusion"
const GLOW: StringName = &"Glow"
const MESH_DETAIL: StringName = &"MeshDetail"
const TEXTURE_FILTERING: StringName = &"TextureFiltering"
const CROWD_DETAIL: StringName = &"CrowdDetail"
const MAX_FPS: StringName = &"MaxFps"

const DEFAULT_PRESET: Preset = Preset.HIGH
## Value of each setting per preset (low, medium, high, ultra)
const PRESET_VALUES: Dictionary[StringName, Array] = {
	RENDER_SCALE: [0.75, 1.0, 1.0, 1.0],
	# Without MSAA the far court lines (thinner than a pixel) break up, so all presets keep it.
	MSAA: [Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X],
	SCREEN_SPACE_AA:
	[
		Viewport.SCREEN_SPACE_AA_FXAA,
		Viewport.SCREEN_SPACE_AA_FXAA,
		Viewport.SCREEN_SPACE_AA_SMAA,
		Viewport.SCREEN_SPACE_AA_SMAA,
	],
	SHADOWS: [Shadows.LOW, Shadows.MEDIUM, Shadows.HIGH, Shadows.ULTRA],
	AMBIENT_OCCLUSION:
	[
		AmbientOcclusion.OFF,
		AmbientOcclusion.LOW,
		AmbientOcclusion.MEDIUM,
		AmbientOcclusion.HIGH,
	],
	GLOW: [false, true, true, true],
	MESH_DETAIL: [4.0, 2.0, 1.0, 0.5],
	TEXTURE_FILTERING:
	[
		Viewport.ANISOTROPY_4X,
		Viewport.ANISOTROPY_8X,
		Viewport.ANISOTROPY_16X,
		Viewport.ANISOTROPY_16X,
	],
	CROWD_DETAIL: [Crowd.Detail.LOW, Crowd.Detail.MEDIUM, Crowd.Detail.HIGH, Crowd.Detail.ULTRA],
}
## Not part of the presets: frames per second at most (0: no limit)
const DEFAULT_MAX_FPS: int = 0

## Directional shadows per Shadows level: the shadow map size, how the view is split into cascades,
## and how soft the shadow edges are filtered
const SHADOW_ATLAS_SIZES: Array[int] = [0, 2048, 4096, 4096, 8192]
const SHADOW_MODES: Array[DirectionalLight3D.ShadowMode] = [
	DirectionalLight3D.SHADOW_ORTHOGONAL,
	DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
	DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
	DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
	DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
]
const SHADOW_FILTERS: Array[RenderingServer.ShadowQuality] = [
	RenderingServer.SHADOW_QUALITY_HARD,
	RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
]
## Ambient occlusion per AmbientOcclusion level (OFF turns it off instead): its quality and
## whether it is computed at half resolution
const SSAO_QUALITIES: Array[RenderingServer.EnvironmentSSAOQuality] = [
	RenderingServer.ENV_SSAO_QUALITY_VERY_LOW,
	RenderingServer.ENV_SSAO_QUALITY_VERY_LOW,
	RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
	RenderingServer.ENV_SSAO_QUALITY_HIGH,
]
const SSAO_HALF_SIZE: Array[bool] = [true, true, true, false]
## Godot's defaults for the rest of the ambient occlusion settings
const SSAO_ADAPTIVE_TARGET: float = 0.5
const SSAO_BLUR_PASSES: int = 2
const SSAO_FADEOUT_FROM: float = 50.0
const SSAO_FADEOUT_TO: float = 300.0

## Metadata keeping what a scene was made with, so the settings can turn effects off and back on
## where the scene has them only
const DESIGNED_SHADOWS: StringName = &"graphics_designed_shadows"
const DESIGNED_SSAO: StringName = &"graphics_designed_ssao"
const DESIGNED_GLOW: StringName = &"graphics_designed_glow"


func _ready() -> void:
	get_tree().node_added.connect(_configure)
	_apply()


## Current value of a setting (one of the keys of PRESET_VALUES, or MAX_FPS).
func get_value(key: StringName) -> Variant:
	var default: Variant = DEFAULT_MAX_FPS
	if key != MAX_FPS:
		default = PRESET_VALUES[key][DEFAULT_PRESET]
	return PlayerConfig.get_config(SECTION, key, default)


func get_preset() -> Preset:
	return PlayerConfig.get_config(SECTION, PRESET, DEFAULT_PRESET)


## Sets all settings of `preset` (not CUSTOM) and applies them.
func select_preset(preset: Preset) -> void:
	PlayerConfig.set_config(SECTION, PRESET, preset)
	for key in PRESET_VALUES:
		PlayerConfig.set_config(SECTION, key, PRESET_VALUES[key][preset])
	_apply()


## Sets one setting and applies it. The preset becomes the one all settings now match, or CUSTOM.
func set_value(key: StringName, value: Variant) -> void:
	PlayerConfig.set_config(SECTION, key, value)
	if key != MAX_FPS:
		PlayerConfig.set_config(SECTION, PRESET, _matching_preset())
	_apply()


func _matching_preset() -> Preset:
	for preset in [Preset.LOW, Preset.MEDIUM, Preset.HIGH, Preset.ULTRA]:
		var matches: bool = true
		for key in PRESET_VALUES:
			if get_value(key) != PRESET_VALUES[key][preset]:
				matches = false
				break
		if matches:
			return preset
	return Preset.CUSTOM


## Applies the settings to the renderer and to everything in the tree.
func _apply() -> void:
	Engine.max_fps = get_value(MAX_FPS)
	var shadows: Shadows = get_value(SHADOWS)
	if shadows != Shadows.OFF:
		RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_SIZES[shadows], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTERS[shadows])
	var ambient_occlusion: AmbientOcclusion = get_value(AMBIENT_OCCLUSION)
	RenderingServer.environment_set_ssao_quality(
		SSAO_QUALITIES[ambient_occlusion],
		SSAO_HALF_SIZE[ambient_occlusion],
		SSAO_ADAPTIVE_TARGET,
		SSAO_BLUR_PASSES,
		SSAO_FADEOUT_FROM,
		SSAO_FADEOUT_TO
	)
	_configure_tree(get_tree().root)


func _configure_tree(node: Node) -> void:
	_configure(node)
	for child in node.get_children(true):
		_configure_tree(child)


## Applies the settings that belong to `node`, if any.
func _configure(node: Node) -> void:
	if node is Viewport:
		_configure_viewport(node)
	elif node is DirectionalLight3D:
		_configure_light(node)
	elif node is WorldEnvironment:
		_configure_environment((node as WorldEnvironment).environment)
	elif node is Crowd:
		(node as Crowd).detail = get_value(CROWD_DETAIL)


func _configure_viewport(viewport: Viewport) -> void:
	var render_scale: float = get_value(RENDER_SCALE)
	viewport.scaling_3d_mode = (
		Viewport.SCALING_3D_MODE_FSR if render_scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	)
	viewport.scaling_3d_scale = render_scale
	viewport.msaa_3d = get_value(MSAA)
	viewport.screen_space_aa = get_value(SCREEN_SPACE_AA)
	viewport.mesh_lod_threshold = get_value(MESH_DETAIL)
	viewport.anisotropic_filtering_level = get_value(TEXTURE_FILTERING)


func _configure_light(light: DirectionalLight3D) -> void:
	if not light.has_meta(DESIGNED_SHADOWS):
		light.set_meta(DESIGNED_SHADOWS, light.shadow_enabled)
	var shadows: Shadows = get_value(SHADOWS)
	light.shadow_enabled = light.get_meta(DESIGNED_SHADOWS) and shadows != Shadows.OFF
	light.directional_shadow_mode = SHADOW_MODES[shadows]


func _configure_environment(environment: Environment) -> void:
	if not environment.has_meta(DESIGNED_SSAO):
		environment.set_meta(DESIGNED_SSAO, environment.ssao_enabled)
		environment.set_meta(DESIGNED_GLOW, environment.glow_enabled)
	environment.ssao_enabled = (
		environment.get_meta(DESIGNED_SSAO) and get_value(AMBIENT_OCCLUSION) != AmbientOcclusion.OFF
	)
	environment.glow_enabled = environment.get_meta(DESIGNED_GLOW) and get_value(GLOW)
