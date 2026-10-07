@tool
class_name CrowdPerson
extends Node3D
## One spectator: a random model with random colors. For performance with large crowds,
## spectators cast no shadows and share their tinted materials; only a share of them is
## animated (see CrowdAnimationStateMachine).

## Tinted materials shared by all spectators, by source material and color
static var _tinted_materials: Dictionary[String, StandardMaterial3D] = {}

var config: CrowdConfig

var _animation_state_machine: CrowdAnimationStateMachine


func _ready() -> void:
	var model: Node3D = config.models.pick_random().instantiate()
	add_child(model)
	_setup_meshes(model)
	var animation_player: AnimationPlayer = model.find_child("AnimationPlayer")
	_animation_state_machine = CrowdAnimationStateMachine.new(animation_player, config)
	_animation_state_machine.start_idle()


func play_victory_animation() -> void:
	_animation_state_machine.play_victory_animation()


## Turns shadows off and tints clothes, hair and skin with random palette colors.
func _setup_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is MeshInstance3D:
		var colors: PackedColorArray = _palette_colors(node.name.to_lower())
		if not colors.is_empty():
			var color: Color = CrowdColorPalette.pick(colors)
			for i in node.get_surface_override_material_count():
				var material: Material = node.get_active_material(i)
				if material is StandardMaterial3D:
					node.set_surface_override_material(i, _tinted_material(material, color))
	for child in node.get_children():
		_setup_meshes(child)


## Palette colors for a mesh by its name, empty for meshes that keep their color.
func _palette_colors(mesh_name: String) -> PackedColorArray:
	var palette: CrowdColorPalette = config.color_palette
	for part in ["shirt", "top", "cloth", "upper"]:
		if part in mesh_name:
			return palette.shirt_colors
	for part in ["pants", "shorts", "leg", "lower"]:
		if part in mesh_name:
			return palette.shorts_colors
	if "hair" in mesh_name:
		return palette.hair_colors
	if "skin" in mesh_name or "face" in mesh_name:
		return palette.skin_colors
	return PackedColorArray()


## Shared copy of `material` tinted with `color`.
static func _tinted_material(material: StandardMaterial3D, color: Color) -> StandardMaterial3D:
	var key: String = "%d:%s" % [material.get_instance_id(), color.to_html()]
	if not _tinted_materials.has(key):
		var tinted := material.duplicate() as StandardMaterial3D
		tinted.albedo_color = color
		_tinted_materials[key] = tinted
	return _tinted_materials[key]
