## Player model: appearance, animation and stroke clips (racket contact points). The body (rig
## and meshes) can turn away from the player's facing, e.g. to run backward; the stroke clips
## keep the player's facing. The longer the match, the more the player sweats: the skin gets wet
## and shiny, the shirt soaks through and drops fly off the head when it runs.
class_name Model
extends Node3D

const HAIR_SHADER: Shader = preload("res://scenes/player/hair.gdshader")
const SWEAT_PATCHES_SHADER: Shader = preload("res://scenes/player/sweat_patches.gdshader")
## Appearance every player's appearance builds on
const BASE_APPEARANCE: PlayerAppearance = preload(
	"res://scenes/player/resources/appearances/base.tres"
)
## Sweat at the start of a match (warmed up) and the match time (s) after which it is full
const START_SWEAT: float = 0.1
const FULL_SWEAT_MATCH_TIME: float = 5400.0
## Fully sweating: skin roughness and clearcoat (a wet film); the shirt soaks through in patches
## (see sweat_patches.gdshader).
const SWEAT_SKIN_ROUGHNESS: float = 0.25
const SWEAT_SKIN_CLEARCOAT: float = 0.6
## Running speed (m/s) at which a fully sweating player sheds the most drops
const SWEAT_DROP_SPEED: float = 5.0
## How fast (rad/s) the body turns
const BODY_TURN_SPEED: float = 10.0

@export var animator: PlayerAnimator
## Racket held in the right hand of the rig.
@export var racket: Racket

## The player's appearance merged onto the base appearance (see load_appearance)
var appearance: PlayerAppearance
## How much the player sweats, in [0, 1]
var sweat: float = 0.0

## Yaw (rad) of the body relative to the player's facing, in [-PI, PI]
var body_yaw: float = 0.0
var _stroke_clips: Array[StrokeClip] = []
## Rig root transform with the body facing the player's facing
var _rig_base_transform: Transform3D

## Skin material and its dry roughness, and the sweat patches drawn over the shirt
var _skin_material: StandardMaterial3D
var _dry_skin_roughness: float
var _sweat_patches: ShaderMaterial

@onready var toss_point: Vector3 = $Points/BallTossPoint.position

@onready var _rig_root: Node3D = $h
@onready var _mesh_root: Node3D = $MeshRoot
@onready var _body_mesh: MeshInstance3D = $MeshRoot/BodyMesh
@onready var _shirt_mesh: MeshInstance3D = $MeshRoot/ShirtMesh
@onready var _shorts_mesh: MeshInstance3D = $MeshRoot/ShortsMesh
@onready var _shoes_mesh: MeshInstance3D = $MeshRoot/ShoesMesh
@onready var _hair_mesh: MeshInstance3D = $MeshRoot/HairMesh
@onready var _sweat_drops: GPUParticles3D = %SweatDrops


func _ready() -> void:
	_rig_base_transform = _rig_root.transform
	set_body_yaw(0.0)
	_collect_stroke_clips()


## Turns the body toward `yaw` (rad, relative to the player's facing) the shorter way round, at
## BODY_TURN_SPEED.
func turn_body_toward(yaw: float, delta: float) -> void:
	var max_step: float = BODY_TURN_SPEED * delta
	set_body_yaw(body_yaw + clampf(wrapf(yaw - body_yaw, -PI, PI), -max_step, max_step))


func set_body_yaw(yaw: float) -> void:
	body_yaw = wrapf(yaw, -PI, PI)
	_rig_root.transform = Transform3D(Basis(Vector3.UP, body_yaw)) * _rig_base_transform
	# MeshRoot must match the rig root transform, otherwise the skinned meshes face backward.
	_mesh_root.transform = _rig_root.transform


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
	appearance = player_appearance.merged_onto(BASE_APPEARANCE)
	_body_mesh.mesh = appearance.body_mesh
	_shirt_mesh.mesh = appearance.shirt_mesh
	_shorts_mesh.mesh = appearance.shorts_mesh
	_shoes_mesh.mesh = appearance.shoes_mesh
	_hair_mesh.mesh = appearance.hair_mesh

	_skin_material = _apply_look(_body_mesh, 0, appearance.skin_texture, appearance.skin_color)
	var shirt_material: StandardMaterial3D = _apply_look(
		_shirt_mesh, 0, appearance.shirt_texture, appearance.shirt_color
	)
	_apply_look(_shorts_mesh, 0, appearance.shorts_texture, appearance.shorts_color)
	_apply_look(_shoes_mesh, 0, appearance.shoes_texture, appearance.shoes_color)
	racket.show_appearance(appearance)
	_apply_hair(appearance.hair_texture, appearance.hair_color)
	_dry_skin_roughness = _skin_material.roughness
	_skin_material.clearcoat_enabled = true
	_sweat_patches = ShaderMaterial.new()
	_sweat_patches.shader = SWEAT_PATCHES_SHADER
	shirt_material.next_pass = _sweat_patches
	set_sweat(sweat)


## Sweats as after `seconds` of match time.
func sweat_after_match_time(seconds: float) -> void:
	set_sweat(lerpf(START_SWEAT, 1.0, clampf(seconds / FULL_SWEAT_MATCH_TIME, 0.0, 1.0)))


## Sets how much the player sweats, in [0, 1].
func set_sweat(level: float) -> void:
	sweat = level
	_skin_material.roughness = lerpf(_dry_skin_roughness, SWEAT_SKIN_ROUGHNESS, sweat)
	_skin_material.clearcoat = SWEAT_SKIN_CLEARCOAT * sweat
	_sweat_patches.set_shader_parameter("sweat", sweat)


## Sheds sweat drops while running at `speed` (m/s): more the faster and the sweatier.
func shed_sweat(speed: float) -> void:
	_sweat_drops.amount_ratio = sweat * clampf(speed / SWEAT_DROP_SPEED, 0.0, 1.0)
	_sweat_drops.emitting = _sweat_drops.amount_ratio > 0.0


## Gives a surface the texture (none for a plain color) tinted with `color`; returns its material.
func _apply_look(
	slot: MeshInstance3D, surface: int, texture: Texture2D, color: Color
) -> StandardMaterial3D:
	var base_material: Material = slot.mesh.surface_get_material(surface)
	var material: StandardMaterial3D = (
		(base_material as StandardMaterial3D).duplicate()
		if base_material is StandardMaterial3D
		else StandardMaterial3D.new()
	)
	material.albedo_texture = texture
	material.albedo_color = color
	slot.set_surface_override_material(surface, material)
	return material


func _apply_hair(texture: Texture2D, color: Color) -> void:
	var material := ShaderMaterial.new()
	material.shader = HAIR_SHADER
	material.set_shader_parameter("hair_texture", texture)
	material.set_shader_parameter("hair_color", color)
	_hair_mesh.material_override = material
