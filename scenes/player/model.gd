## Player model: appearance, animation and stroke clips (racket contact points)
class_name Model
extends Node3D

const HAIR_SHADER: Shader = preload("res://scenes/player/hair.gdshader")
## Appearance every player's appearance builds on
const BASE_APPEARANCE: PlayerAppearance = preload(
	"res://scenes/player/resources/appearances/base.tres"
)
## Surfaces of the racket mesh
const RACKET_STRINGS_SURFACE: int = 0
const RACKET_FRAME_SURFACE: int = 1

@export var animator: PlayerAnimator
## Racket mesh held in the right hand of the rig.
@export var racket_mesh: MeshInstance3D

var _stroke_clips: Array[StrokeClip] = []

@onready var toss_point: Vector3 = $Points/BallTossPoint.position

@onready var _rig_root: Node3D = $h
@onready var _mesh_root: Node3D = $MeshRoot
@onready var _body_mesh: MeshInstance3D = $MeshRoot/BodyMesh
@onready var _shirt_mesh: MeshInstance3D = $MeshRoot/ShirtMesh
@onready var _shorts_mesh: MeshInstance3D = $MeshRoot/ShortsMesh
@onready var _shoes_mesh: MeshInstance3D = $MeshRoot/ShoesMesh
@onready var _hair_mesh: MeshInstance3D = $MeshRoot/HairMesh


func _ready() -> void:
	# MeshRoot must match the rig root transform, otherwise the skinned meshes face backward.
	_mesh_root.transform = _rig_root.transform
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


## Shows the player's appearance on top of the base appearance.
func load_appearance(player_appearance: PlayerAppearance) -> void:
	var appearance: PlayerAppearance = player_appearance.merged_onto(BASE_APPEARANCE)
	_body_mesh.mesh = appearance.body_mesh
	_shirt_mesh.mesh = appearance.shirt_mesh
	_shorts_mesh.mesh = appearance.shorts_mesh
	_shoes_mesh.mesh = appearance.shoes_mesh
	_hair_mesh.mesh = appearance.hair_mesh

	_apply_look(_body_mesh, 0, appearance.skin_texture, appearance.skin_color)
	_apply_look(_shirt_mesh, 0, appearance.shirt_texture, appearance.shirt_color)
	_apply_look(_shorts_mesh, 0, appearance.shorts_texture, appearance.shorts_color)
	_apply_look(_shoes_mesh, 0, appearance.shoes_texture, appearance.shoes_color)
	_apply_look(racket_mesh, RACKET_FRAME_SURFACE, appearance.racket_texture, Color.WHITE)
	_apply_look(racket_mesh, RACKET_STRINGS_SURFACE, appearance.racket_strings_texture, Color.WHITE)
	_apply_hair(appearance.hair_texture, appearance.hair_color)


## Gives a surface the texture (none for a plain color) tinted with `color`.
func _apply_look(slot: MeshInstance3D, surface: int, texture: Texture2D, color: Color) -> void:
	var base_material: Material = slot.mesh.surface_get_material(surface)
	var material: StandardMaterial3D = (
		(base_material as StandardMaterial3D).duplicate()
		if base_material is StandardMaterial3D
		else StandardMaterial3D.new()
	)
	material.albedo_texture = texture
	material.albedo_color = color
	slot.set_surface_override_material(surface, material)


func _apply_hair(texture: Texture2D, color: Color) -> void:
	var material := ShaderMaterial.new()
	material.shader = HAIR_SHADER
	material.set_shader_parameter("hair_texture", texture)
	material.set_shader_parameter("hair_color", color)
	_hair_mesh.material_override = material
