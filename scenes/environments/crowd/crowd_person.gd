@tool
class_name CrowdPerson
extends Node3D
## One spectator. For performance with large crowds, spectators cast no shadows and share
## their tinted materials; only a share of them is animated (see CrowdAnimationStateMachine).

## Tinted materials shared by all spectators, by source material and color
static var _tinted_materials: Dictionary = {}

## Configuration resource
var config: CrowdConfig

## Model variant key (e.g., "crowd-1")
var model_key: String = "crowd-1"

## Animation state machine
var animation_state_machine: CrowdAnimationStateMachine

## Reference to the instantiated model
var model: Node3D

## Animation player from the model
var animation_player: AnimationPlayer


func _init(p_config: CrowdConfig = null) -> void:
	if p_config:
		config = p_config
	else:
		config = CrowdConfig.new()


func _ready() -> void:
	if not config.validate():
		push_error("CrowdPerson: Invalid configuration")
		if not Engine.is_editor_hint():
			queue_free()
		return

	if not _instantiate_model():
		push_error("CrowdPerson: Failed to instantiate model '%s'" % model_key)
		if not Engine.is_editor_hint():
			queue_free()
		return

	if not _setup_animation_player():
		push_error("CrowdPerson: Failed to setup animation player")
		if not Engine.is_editor_hint():
			queue_free()
		return

	_setup_animation_state_machine()
	_apply_color_variations()


func start_idle() -> void:
	animation_state_machine.start_idle()


func play_victory_animation() -> void:
	animation_state_machine.play_victory_animation()


func cleanup() -> void:
	if animation_state_machine:
		animation_state_machine.cleanup()
		animation_state_machine = null


# Private methods


func _instantiate_model() -> bool:
	# Load model resource
	var model_path = config.model_paths.get(model_key, "")
	if model_path.is_empty():
		push_error("CrowdPerson: Model path not found for '%s'" % model_key)
		return false

	var resource = load(model_path)
	if not resource:
		push_error("CrowdPerson: Failed to load model from '%s'" % model_path)
		return false

	if not resource is PackedScene:
		push_error("CrowdPerson: Resource at '%s' is not a PackedScene" % model_path)
		return false

	model = resource.instantiate()
	if not model:
		push_error("CrowdPerson: Failed to instantiate model from '%s'" % model_path)
		return false

	add_child(model)
	_disable_shadows(model)
	return true


func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)


func _setup_animation_player() -> bool:
	# Try to find AnimationPlayer in the instantiated model
	# First try direct child with model name
	var anim_player = model.find_child("AnimationPlayer")
	if not anim_player:
		push_error("CrowdPerson: AnimationPlayer not found in model '%s'" % model_key)
		return false

	if not anim_player is AnimationPlayer:
		push_error("CrowdPerson: Found node is not an AnimationPlayer")
		return false

	animation_player = anim_player
	return true


func _setup_animation_state_machine() -> void:
	animation_state_machine = CrowdAnimationStateMachine.new(animation_player, config)
	add_child(animation_state_machine)


func _apply_color_variations() -> void:
	if not config or not config.apply_color_variations:
		return

	var palette = config.get_color_palette()
	if not palette:
		return

	# Recursively find and color all mesh instances in the model
	_colorize_node(model, palette)


# Private methods for color variations


func _colorize_node(node: Node, palette: CrowdColorPalette) -> void:
	if node is MeshInstance3D:
		_apply_colors_to_mesh_instance(node as MeshInstance3D, palette)

	# Recursively process children
	for child in node.get_children():
		_colorize_node(child, palette)


func _apply_colors_to_mesh_instance(
	mesh_instance: MeshInstance3D, palette: CrowdColorPalette
) -> void:
	var name_lower = mesh_instance.name.to_lower()

	# Determine what color to apply based on mesh name
	var color_to_apply: Color
	var should_apply = true

	if (
		"shirt" in name_lower
		or "top" in name_lower
		or "cloth" in name_lower
		or "upper" in name_lower
	):
		color_to_apply = palette.get_random_shirt_color()
	elif (
		"pants" in name_lower
		or "shorts" in name_lower
		or "legs" in name_lower
		or "leg" in name_lower
		or "lower" in name_lower
	):
		color_to_apply = palette.get_random_shorts_color()
	elif "hair" in name_lower:
		color_to_apply = palette.get_random_hair_color()
	elif "skin" in name_lower or "face" in name_lower:
		color_to_apply = palette.get_random_skin_color()
	else:
		should_apply = false

	if not should_apply:
		return

	for i in range(mesh_instance.get_surface_override_material_count()):
		var material: Material = mesh_instance.get_active_material(i)
		if material is StandardMaterial3D:
			mesh_instance.set_surface_override_material(
				i, _tinted_material(material as StandardMaterial3D, color_to_apply)
			)


## Shared copy of `material` tinted with `color`.
static func _tinted_material(material: StandardMaterial3D, color: Color) -> StandardMaterial3D:
	var key: String = "%d:%s" % [material.get_instance_id(), color.to_html()]
	if not _tinted_materials.has(key):
		var tinted := material.duplicate() as StandardMaterial3D
		tinted.albedo_color = color
		_tinted_materials[key] = tinted
	return _tinted_materials[key]
