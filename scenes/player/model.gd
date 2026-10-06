## Player model: appearance, animation and stroke clips (racket contact points)
class_name Model
extends Node3D

const DEFAULT_APPEARANCE: PlayerAppearance = preload(
	"res://scenes/player/resources/appearances/djokovic.tres"
)

@export var animator: PlayerAnimator

var _active_body_proportions: Dictionary = {}
var _stroke_clips: Array[StrokeClip] = []

@onready var toss_point: Vector3 = $Points/BallTossPoint.position

@onready var _legacy_root: Node3D = $h
@onready var _legacy_visual_root: Node3D = $h/player_djokovic
@onready var _mesh_root: Node3D = $MeshRoot
@onready var _body_mesh: MeshInstance3D = $MeshRoot/BodyMesh
@onready var _shirt_mesh: MeshInstance3D = $MeshRoot/ShirtMesh
@onready var _shorts_mesh: MeshInstance3D = $MeshRoot/ShortsMesh
@onready var _shoes_mesh: MeshInstance3D = $MeshRoot/ShoesMesh
@onready var _hair_mesh: MeshInstance3D = $MeshRoot/HairMesh


func _ready() -> void:
	# MeshRoot must match the legacy rig root transform,
	# otherwise skinned modular meshes face backward.
	_mesh_root.transform = _legacy_root.transform
	_mesh_root.visible = false
	_set_legacy_visual_state(true)
	_collect_stroke_clips()


func _collect_stroke_clips() -> void:
	for child in $Points.get_children():
		if not child is StrokeClip:
			continue
		var clip: StrokeClip = child
		assert(
			animator.has_stroke_animation(clip.animation),
			(
				"StrokeClip %s: '%s' is not a stroke animation of the AnimationTree"
				% [clip.name, clip.animation]
			)
		)
		assert(
			animator.get_animation(clip.animation).has_marker(PlayerAnimator.HIT_MARKER),
			"StrokeClip %s: '%s' has no 'hit' marker" % [clip.name, clip.animation]
		)
		_stroke_clips.append(clip)


## Clip used to play the stroke: the one for its type whose contact height is closest to the ball.
func get_stroke_clip(stroke: Stroke) -> StrokeClip:
	var best_clip: StrokeClip = null
	var best_height_error: float = INF
	for clip in _stroke_clips:
		if not clip.supports(stroke.stroke_type):
			continue
		var height_error: float = 0.0
		if stroke.step:
			height_error = absf(clip.global_position.y - stroke.step.point.y)
		if height_error < best_height_error:
			best_height_error = height_error
			best_clip = clip

	assert(best_clip != null, "Model: no StrokeClip for stroke type %d" % stroke.stroke_type)
	return best_clip


## World position where the racket meets the ball for the given stroke.
func get_racket_contact_point(stroke: Stroke) -> Vector3:
	return get_stroke_clip(stroke).global_position


func load_appearance(appearance: PlayerAppearance) -> void:
	if appearance == null:
		push_error("Model.load_appearance: appearance is required")
		return

	var fallback: PlayerAppearance = DEFAULT_APPEARANCE
	var resolved_body_mesh: Mesh = _resolve_resource(appearance.body_mesh, fallback.body_mesh)
	var resolved_shirt_mesh: Mesh = _resolve_resource(appearance.shirt_mesh, fallback.shirt_mesh)
	var resolved_shorts_mesh: Mesh = _resolve_resource(appearance.shorts_mesh, fallback.shorts_mesh)
	var resolved_shoes_mesh: Mesh = _resolve_resource(appearance.shoes_mesh, fallback.shoes_mesh)
	var resolved_hair_mesh: Mesh = _resolve_resource(appearance.hair_mesh, fallback.hair_mesh)

	var resolved_body_texture: Texture2D = _resolve_resource(
		_resolve_resource(appearance.body_texture, appearance.skin_texture),
		_resolve_resource(fallback.body_texture, fallback.skin_texture)
	)
	var resolved_face_texture: Texture2D = _resolve_resource(
		appearance.face_texture, fallback.face_texture
	)
	var resolved_shirt_texture: Texture2D = _resolve_resource(
		appearance.shirt_texture, fallback.shirt_texture
	)
	var resolved_shorts_texture: Texture2D = _resolve_resource(
		appearance.shorts_texture, fallback.shorts_texture
	)
	var resolved_shoes_texture: Texture2D = _resolve_resource(
		appearance.shoes_texture, fallback.shoes_texture
	)
	var resolved_hair_texture: Texture2D = _resolve_resource(
		appearance.hair_texture, fallback.hair_texture
	)
	var resolved_racket_texture: Texture2D = _resolve_resource(
		appearance.racket_texture, fallback.racket_texture
	)
	var resolved_racket_strings_texture: Texture2D = _resolve_resource(
		appearance.racket_strings_texture, fallback.racket_strings_texture
	)

	var resolved_body_proportions: Dictionary = _resolve_dictionary(
		appearance.body_proportions, fallback.body_proportions
	)

	clear_appearance()

	_body_mesh.mesh = resolved_body_mesh
	_shirt_mesh.mesh = resolved_shirt_mesh
	_shorts_mesh.mesh = resolved_shorts_mesh
	_shoes_mesh.mesh = resolved_shoes_mesh
	_hair_mesh.mesh = resolved_hair_mesh

	_apply_texture_to_slot(_body_mesh, resolved_body_texture)
	_apply_face_texture_hook(resolved_face_texture)
	_apply_texture_to_slot(_shirt_mesh, resolved_shirt_texture)
	_apply_texture_to_slot(_shorts_mesh, resolved_shorts_texture)
	_apply_texture_to_slot(_shoes_mesh, resolved_shoes_texture)
	_apply_texture_to_slot(_hair_mesh, resolved_hair_texture)
	_apply_racket_texture_hooks(resolved_racket_texture, resolved_racket_strings_texture)
	_apply_proportion_hooks(resolved_body_proportions)

	var using_modular_meshes: bool = (
		resolved_body_mesh != null
		or resolved_shirt_mesh != null
		or resolved_shorts_mesh != null
		or resolved_shoes_mesh != null
		or resolved_hair_mesh != null
	)
	_mesh_root.transform = _legacy_root.transform
	_mesh_root.visible = using_modular_meshes
	_set_legacy_visual_state(not using_modular_meshes)

	if not using_modular_meshes:
		push_warning(
			"Model.load_appearance: appearance has no modular meshes yet; using legacy model mesh"
		)


func clear_appearance() -> void:
	_body_mesh.mesh = null
	_shirt_mesh.mesh = null
	_shorts_mesh.mesh = null
	_shoes_mesh.mesh = null
	_hair_mesh.mesh = null
	_active_body_proportions.clear()


func _apply_proportion_hooks(proportions: Dictionary) -> void:
	# Phase-one hook: store values for later skeleton/body deformation pass.
	if proportions == null:
		_active_body_proportions = {}
		return

	_active_body_proportions = proportions.duplicate(true)


func _apply_texture_to_slot(slot: MeshInstance3D, texture: Texture2D) -> void:
	if slot == null or not _is_texture_usable(texture):
		return

	if slot.material_override and slot.material_override is StandardMaterial3D:
		var override_material: StandardMaterial3D = (
			(slot.material_override as StandardMaterial3D).duplicate()
		)
		if override_material == null:
			return
		override_material.albedo_texture = texture
		slot.material_override = override_material
		return

	if slot.mesh == null:
		return

	if slot.mesh.get_surface_count() == 0:
		return

	var base_material: Material = slot.get_active_material(0)
	if base_material is StandardMaterial3D:
		var duplicated_material: StandardMaterial3D = (
			(base_material as StandardMaterial3D).duplicate()
		)
		if duplicated_material == null:
			return
		duplicated_material.albedo_texture = texture
		slot.set_surface_override_material(0, duplicated_material)


func _apply_face_texture_hook(texture: Texture2D) -> void:
	if not _is_texture_usable(texture):
		return

	# Keep modular body material untouched;
	# apply face textures only to explicit legacy face/head meshes.
	_apply_face_texture_recursive(_legacy_root, texture)


func _apply_racket_texture_hooks(
	racket_texture: Texture2D, racket_strings_texture: Texture2D
) -> void:
	_apply_racket_textures_recursive(_legacy_root, racket_texture, racket_strings_texture)
	_apply_racket_textures_recursive(_mesh_root, racket_texture, racket_strings_texture)


func _apply_face_texture_recursive(node: Node, texture: Texture2D) -> void:
	if node is MeshInstance3D:
		var node_name: String = node.name.to_lower()
		if (
			(node_name.contains("face") or node_name.contains("head"))
			and not node_name.contains("racket")
			and not node_name.contains("string")
			and not node_name.contains("gut")
		):
			_apply_texture_to_slot(node as MeshInstance3D, texture)

	for child in node.get_children():
		_apply_face_texture_recursive(child, texture)


func _apply_racket_textures_recursive(
	node: Node, racket_texture: Texture2D, racket_strings_texture: Texture2D
) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var node_name: String = mesh_instance.name.to_lower()
		var is_racket_mesh: bool = _mesh_matches_keywords(
			mesh_instance, ["racket", "frame", "head"]
		)
		if node_name.contains("racket"):
			is_racket_mesh = true

		if is_racket_mesh:
			if _is_texture_usable(racket_texture):
				var frame_matches: int = _apply_texture_to_matching_surfaces(
					mesh_instance, racket_texture, ["racket", "frame", "head"], ["string", "gut"]
				)
				if frame_matches == 0:
					_apply_texture_to_slot(mesh_instance, racket_texture)

			if _is_texture_usable(racket_strings_texture):
				var string_matches: int = _apply_texture_to_matching_surfaces(
					mesh_instance, racket_strings_texture, ["string", "gut"], []
				)
				if string_matches == 0:
					_apply_texture_to_fallback_strings_surface(
						mesh_instance, racket_strings_texture
					)

	for child in node.get_children():
		_apply_racket_textures_recursive(child, racket_texture, racket_strings_texture)


func _apply_texture_to_matching_surfaces(
	mesh_instance: MeshInstance3D,
	texture: Texture2D,
	include_keywords: Array,
	exclude_keywords: Array
) -> int:
	if mesh_instance == null or mesh_instance.mesh == null or not _is_texture_usable(texture):
		return 0

	var surface_count: int = mesh_instance.mesh.get_surface_count()
	if surface_count == 0:
		return 0

	var applied_count: int = 0
	for surface_index in surface_count:
		var surface_name: String = mesh_instance.mesh.surface_get_name(surface_index).to_lower()
		var active_material: Material = mesh_instance.get_active_material(surface_index)
		var material_name: String = ""
		if active_material != null:
			material_name = active_material.resource_name.to_lower()

		var matches_include: bool = (
			_name_matches_keywords(surface_name, include_keywords)
			or _name_matches_keywords(material_name, include_keywords)
		)
		var matches_exclude: bool = (
			_name_matches_keywords(surface_name, exclude_keywords)
			or _name_matches_keywords(material_name, exclude_keywords)
		)
		if matches_include and not matches_exclude:
			if _apply_texture_to_surface(mesh_instance, surface_index, texture):
				applied_count += 1

	return applied_count


func _apply_texture_to_fallback_strings_surface(
	mesh_instance: MeshInstance3D, texture: Texture2D
) -> void:
	if mesh_instance == null or mesh_instance.mesh == null or not _is_texture_usable(texture):
		return

	var surface_count: int = mesh_instance.mesh.get_surface_count()
	if surface_count <= 0:
		return

	# Most racket imports keep strings as a dedicated non-primary surface.
	var fallback_surface_index: int = 0
	if surface_count > 1:
		fallback_surface_index = surface_count - 1

	_apply_texture_to_surface(mesh_instance, fallback_surface_index, texture)


func _apply_texture_to_surface(
	slot: MeshInstance3D, surface_index: int, texture: Texture2D
) -> bool:
	if slot == null or slot.mesh == null or not _is_texture_usable(texture):
		return false

	if surface_index < 0 or surface_index >= slot.mesh.get_surface_count():
		return false

	var base_material: Material = slot.get_active_material(surface_index)
	if base_material is StandardMaterial3D:
		var duplicated_material: StandardMaterial3D = (
			(base_material as StandardMaterial3D).duplicate()
		)
		if duplicated_material == null:
			return false
		duplicated_material.albedo_texture = texture
		slot.set_surface_override_material(surface_index, duplicated_material)
		return true

	return false


func _mesh_matches_keywords(mesh_instance: MeshInstance3D, keywords: Array) -> bool:
	if mesh_instance == null or mesh_instance.mesh == null:
		return false

	var surface_count: int = mesh_instance.mesh.get_surface_count()
	for surface_index in surface_count:
		var surface_name: String = mesh_instance.mesh.surface_get_name(surface_index).to_lower()
		if _name_matches_keywords(surface_name, keywords):
			return true

		var active_material: Material = mesh_instance.get_active_material(surface_index)
		if (
			active_material != null
			and _name_matches_keywords(active_material.resource_name.to_lower(), keywords)
		):
			return true

	return false


func _name_matches_keywords(name_text: String, keywords: Array) -> bool:
	if name_text.is_empty() or keywords.is_empty():
		return false

	for keyword in keywords:
		if name_text.contains(str(keyword).to_lower()):
			return true

	return false


func _set_legacy_visual_state(show_legacy_character: bool) -> void:
	# Keep rig/attachments active; toggle only visual meshes and always keep racket meshes visible.
	_legacy_visual_root.visible = true
	_set_legacy_mesh_visibility_recursive(_legacy_visual_root, show_legacy_character)


func _set_legacy_mesh_visibility_recursive(node: Node, show_legacy_character: bool) -> void:
	if node is MeshInstance3D:
		var mesh_name: String = node.name.to_lower()
		if _should_keep_legacy_mesh_visible(mesh_name):
			node.visible = true
		else:
			node.visible = show_legacy_character

	for child in node.get_children():
		_set_legacy_mesh_visibility_recursive(child, show_legacy_character)


func _should_keep_legacy_mesh_visible(mesh_name: String) -> bool:
	return (
		mesh_name.contains("racket")
		or mesh_name.contains("string")
		or mesh_name.contains("gut")
		or mesh_name.contains("head")
		or mesh_name.contains("face")
		or mesh_name.contains("eye")
		or mesh_name.contains("brow")
		or mesh_name.contains("lash")
		or mesh_name.contains("teeth")
		or mesh_name.contains("tongue")
	)


func _is_texture_usable(texture: Texture2D) -> bool:
	if texture == null or not is_instance_valid(texture):
		return false

	if not texture.resource_path.is_empty() and not ResourceLoader.exists(texture.resource_path):
		return false

	var texture_rid: RID = texture.get_rid()
	if not texture_rid.is_valid():
		return false

	return true


func _resolve_resource(primary, fallback):
	if primary != null:
		return primary
	return fallback


func _resolve_dictionary(primary: Dictionary, fallback: Dictionary) -> Dictionary:
	if primary != null and not primary.is_empty():
		return primary
	if fallback == null:
		return {}
	return fallback
