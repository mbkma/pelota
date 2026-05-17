## Player model with animations, skeleton points, and stroke handling
class_name Model
extends Node3D

const DEFAULT_APPEARANCE: PlayerAppearance = preload("res://scenes/player/resources/appearances/djokovic.tres")

## Emitted when stroke animation finishes
signal stroke_animation_finished

## Emitted when recovery animation finishes
signal recovery_animation_finished

## Emitted when the active ball enters the racket hit area
signal hit_area_ball_entered(ball: Ball)

## Reference to parent player
var player: Player

## Track last animation state for detecting transitions
var _last_state: String = ""

## Track if stroke animation finished signal was already emitted
var _stroke_finished_emitted: bool = false

@onready var points: Node3D = $Points
@onready var toss_point: Vector3 = points.get_node("BallTossPoint").position
@onready var forehand_up_point: Vector3 = points.get_node("ForehandUpPoint").position
@onready var forehand_point: Marker3D = $Points/ForehandPoint
@onready var forehand_down_point: Vector3 = points.get_node("ForehandDownPoint").position
@onready var backhand_up_point: Vector3 = points.get_node("BackhandUpPoint").position
@onready var backhand_down_point: Vector3 = points.get_node("BackhandDownPoint").position
@onready var backhand_point: Marker3D = $Points/BackhandPoint

@export var animation_tree: AnimationTree
@onready var _playback: AnimationNodeStateMachinePlayback = (
	animation_tree.get("parameters/playback")
)

## Reference to the AnimationPlayer that drives the animation tree
@onready var _animation_player: AnimationPlayer = animation_tree.get_node(animation_tree.anim_player)

## Mapping from stroke type to animation name for lookup
var _stroke_animation_names: Dictionary = {
	Stroke.StrokeType.FOREHAND: "g_forehand",
	Stroke.StrokeType.BACKHAND: "g_backhand",
	Stroke.StrokeType.BACKHAND_SLICE: "g_backhand_slice",
	Stroke.StrokeType.BACKHAND_DROP_SHOT: "g_backhand_slice",
	Stroke.StrokeType.SERVE: "g_serve",
	Stroke.StrokeType.VOLLEY: "g_volley",
	Stroke.StrokeType.FOREHAND_DROP_SHOT: "g_forehand",
}
var _replay_animation_paused: bool = false
var _active_body_proportions: Dictionary = {}

@onready var _legacy_root: Node3D = $h
@onready var _legacy_visual_root: Node3D = $h/player_djokovic
@onready var _mesh_root: Node3D = $MeshRoot
@onready var _body_mesh: MeshInstance3D = $MeshRoot/BodyMesh
@onready var _shirt_mesh: MeshInstance3D = $MeshRoot/ShirtMesh
@onready var _shorts_mesh: MeshInstance3D = $MeshRoot/ShortsMesh
@onready var _shoes_mesh: MeshInstance3D = $MeshRoot/ShoesMesh
@onready var _hair_mesh: MeshInstance3D = $MeshRoot/HairMesh


func _ready() -> void:
	var p = get_parent()
	if not p is Player:
		push_error("Model parent must be Player, got: " + str(p))
		set_process(false)
		return

	player = p
	animation_tree.active = true
	# MeshRoot must match the legacy rig root transform, otherwise skinned modular meshes face backward.
	_mesh_root.transform = _legacy_root.transform
	_mesh_root.visible = false
	_set_legacy_visual_state(true)


func _process(_delta: float) -> void:
	if _replay_animation_paused:
		return

	if not _playback:
		return

	var current_state: String = _playback.get_current_node()

	# Detect when we transition away from stroke state
	if _last_state == "stroke" and current_state != "stroke" and not _stroke_finished_emitted:
		_stroke_finished_emitted = true
		stroke_animation_finished.emit()

	# Reset flag when entering stroke state
	if current_state == "stroke":
		_stroke_finished_emitted = false

	_last_state = current_state


func get_animation_hit_frame_time(stroke_type: Stroke.StrokeType) -> float:
	var anim_name: String = _stroke_animation_names.get(stroke_type, "")
	var animation: Animation = _animation_player.get_animation(anim_name)

	return animation.get_marker_time("hit")


func _on_hit_area_3d_body_entered(body: Node3D) -> void:
	if body is Ball:
		hit_area_ball_entered.emit(body)

## Called from animation timeline to spawn the ball (forwarded to player)
func _from_anim_spawn_ball() -> void:
	player.from_anim_spawn_ball()

## Called from animation timeline to hit the serve (forwarded to player)
func from_anim_hit_serve() -> void:
	player.from_anim_hit_serve()

## Called from animation timeline to hit the ball
func _from_anim_hit_ball() -> void:
	print("_from_anim_hit_ball")
	player._from_anim_hit_ball()


func get_racket_contact_point(stroke: Stroke) -> Vector3:
	if stroke:
		match stroke.stroke_type:
			Stroke.StrokeType.FOREHAND, Stroke.StrokeType.FOREHAND_DROP_SHOT, Stroke.StrokeType.VOLLEY:
				return forehand_point.global_position
			Stroke.StrokeType.BACKHAND, Stroke.StrokeType.BACKHAND_SLICE, Stroke.StrokeType.BACKHAND_DROP_SHOT:
				return backhand_point.global_position

	return global_position

func compute_stroke_blend_position(stroke: Stroke) -> float:
	if not stroke or not stroke.step:
		return 0.5

	var numerator: float = 0.0
	var denominator: float = 1.0

	match stroke.stroke_type:
		stroke.StrokeType.FOREHAND:
			numerator = stroke.step.point.y - forehand_down_point.y
			denominator = forehand_up_point.y - forehand_down_point.y
		stroke.StrokeType.BACKHAND:
			numerator = stroke.step.point.y - backhand_down_point.y
			denominator = backhand_up_point.y - backhand_down_point.y
		_:
			return 0.5

	if is_zero_approx(denominator):
		return 0.5

	var blend_position: float = numerator / denominator
	if not is_finite(blend_position):
		return 0.5

	return clampf(blend_position, 0.0, 1.0)


## Animation API
################

## Play idle animation
func play_idle() -> void:
	_playback.travel("move")
	animation_tree["parameters/move/blend_position"] = Vector2.ZERO


## Play run animation in given direction
func play_run(direction: Vector3) -> void:
	# Transform world-space direction to player's local space
	var local_direction: Vector3 = player.global_transform.basis.inverse() * direction
	var dir: Vector2 = Vector2(local_direction.x, -local_direction.z)
	animation_tree["parameters/move/blend_position"] = dir
	_playback.travel("move")


## Play stroke animation for given stroke
func play_stroke(stroke: Stroke) -> void:
	var playback_speed = 1.0

	animation_tree.set("parameters/stroke/TimeScale/scale", playback_speed)
	_set_stroke_animation(stroke)
	_playback.travel("stroke")


## Play recovery animation after stroke finishes
func play_recovery() -> void:
	_playback.travel("move")
	animation_tree["parameters/move/blend_position"] = Vector2.ZERO
	recovery_animation_finished.emit()


func get_replay_animation_snapshot() -> Dictionary:
	var state_node: String = ""
	if _playback:
		state_node = str(_playback.get_current_node())

	var current_animation: String = _animation_player.current_animation
	var current_position: float = 0.0
	if not current_animation.is_empty() and _animation_player.has_animation(current_animation):
		current_position = _animation_player.current_animation_position

	return {
		"state_node": state_node,
		"current_animation": current_animation,
		"current_position": current_position,
		"move_blend": animation_tree.get("parameters/move/blend_position"),
	}


func apply_replay_animation_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return

	var state_node: String = snapshot.get("state_node", "")
	if not state_node.is_empty() and _playback:
		_playback.travel(state_node)

	var current_animation: String = snapshot.get("current_animation", "")
	if not current_animation.is_empty() and _animation_player.has_animation(current_animation):
		_animation_player.play(current_animation)
		_animation_player.seek(float(snapshot.get("current_position", 0.0)), true)
		if _replay_animation_paused:
			_animation_player.pause()

	if snapshot.has("move_blend"):
		animation_tree.set("parameters/move/blend_position", snapshot["move_blend"])


func set_replay_animation_paused(paused: bool) -> void:
	_replay_animation_paused = paused
	if paused:
		_animation_player.pause()
	else:
		# Continue only when an actual animation is active.
		var current_animation: String = _animation_player.current_animation
		if not current_animation.is_empty() and _animation_player.has_animation(current_animation):
			_animation_player.play()


## Internal helper to set stroke animation type and parameters
func _set_stroke_animation(stroke: Stroke) -> void:
	var animation_name: String = _stroke_animation_names.get(stroke.stroke_type, "")

	if animation_name.is_empty():
		push_warning("Stroke animation ", stroke.stroke_type, " not available!")
		return

	if stroke.stroke_type == stroke.StrokeType.FOREHAND or stroke.stroke_type == stroke.StrokeType.BACKHAND:
		var blend_position: float = compute_stroke_blend_position(stroke)
		animation_tree["parameters/stroke/" + animation_name + "/blend_position"] = blend_position
		Loggie.msg("blend position: ", blend_position).info()

	animation_tree["parameters/stroke/Transition/transition_request"] = animation_name


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
	var resolved_face_texture: Texture2D = _resolve_resource(appearance.face_texture, fallback.face_texture)
	var resolved_shirt_texture: Texture2D = _resolve_resource(appearance.shirt_texture, fallback.shirt_texture)
	var resolved_shorts_texture: Texture2D = _resolve_resource(appearance.shorts_texture, fallback.shorts_texture)
	var resolved_shoes_texture: Texture2D = _resolve_resource(appearance.shoes_texture, fallback.shoes_texture)
	var resolved_hair_texture: Texture2D = _resolve_resource(appearance.hair_texture, fallback.hair_texture)
	var resolved_racket_texture: Texture2D = _resolve_resource(appearance.racket_texture, fallback.racket_texture)
	var resolved_racket_strings_texture: Texture2D = _resolve_resource(
		appearance.racket_strings_texture,
		fallback.racket_strings_texture
	)

	var resolved_body_proportions: Dictionary = _resolve_dictionary(
		appearance.body_proportions,
		fallback.body_proportions
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
		push_warning("Model.load_appearance: appearance has no modular meshes yet; using legacy model mesh")


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
		var override_material: StandardMaterial3D = (slot.material_override as StandardMaterial3D).duplicate(true)
		override_material.albedo_texture = texture
		slot.material_override = override_material
		return

	if slot.mesh == null:
		return

	if slot.mesh.get_surface_count() == 0:
		return

	var base_material: Material = slot.get_active_material(0)
	if base_material is StandardMaterial3D:
		var duplicated_material: StandardMaterial3D = (base_material as StandardMaterial3D).duplicate(true)
		duplicated_material.albedo_texture = texture
		slot.set_surface_override_material(0, duplicated_material)


func _apply_face_texture_hook(texture: Texture2D) -> void:
	if not _is_texture_usable(texture):
		return

	# Keep modular body material untouched; apply face textures only to explicit legacy face/head meshes.
	_apply_face_texture_recursive(_legacy_root, texture)


func _apply_racket_texture_hooks(racket_texture: Texture2D, racket_strings_texture: Texture2D) -> void:
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


func _apply_racket_textures_recursive(node: Node, racket_texture: Texture2D, racket_strings_texture: Texture2D) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var node_name: String = mesh_instance.name.to_lower()
		var is_racket_mesh: bool = _mesh_matches_keywords(mesh_instance, ["racket", "frame", "head"])
		if node_name.contains("racket"):
			is_racket_mesh = true

		if is_racket_mesh:
			if _is_texture_usable(racket_texture):
				var frame_matches: int = _apply_texture_to_matching_surfaces(
					mesh_instance,
					racket_texture,
					["racket", "frame", "head"],
					["string", "gut"]
				)
				if frame_matches == 0:
					_apply_texture_to_slot(mesh_instance, racket_texture)

			if _is_texture_usable(racket_strings_texture):
				var string_matches: int = _apply_texture_to_matching_surfaces(
					mesh_instance,
					racket_strings_texture,
					["string", "gut"],
					[]
				)
				if string_matches == 0:
					_apply_texture_to_fallback_strings_surface(mesh_instance, racket_strings_texture)

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

		var matches_include: bool = _name_matches_keywords(surface_name, include_keywords) or _name_matches_keywords(material_name, include_keywords)
		var matches_exclude: bool = _name_matches_keywords(surface_name, exclude_keywords) or _name_matches_keywords(material_name, exclude_keywords)
		if matches_include and not matches_exclude:
			if _apply_texture_to_surface(mesh_instance, surface_index, texture):
				applied_count += 1

	return applied_count


func _apply_texture_to_fallback_strings_surface(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
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


func _apply_texture_to_surface(slot: MeshInstance3D, surface_index: int, texture: Texture2D) -> bool:
	if slot == null or slot.mesh == null or not _is_texture_usable(texture):
		return false

	if surface_index < 0 or surface_index >= slot.mesh.get_surface_count():
		return false

	var base_material: Material = slot.get_active_material(surface_index)
	if base_material is StandardMaterial3D:
		var duplicated_material: StandardMaterial3D = (base_material as StandardMaterial3D).duplicate(true)
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
		if active_material != null and _name_matches_keywords(active_material.resource_name.to_lower(), keywords):
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
