## Player model: body, appearance, animation and stroke clips (racket contact points). The body
## is an imported player body (see scenes/player/rig/player_body_import.gd): its rig and its
## meshes by slot (Body, Shirt, Shorts, Shoes, Hair). It can turn away from the player's facing,
## e.g. to run backward; the stroke clips keep the player's facing. The longer the match, the more
## the player sweats: the skin gets wet and shiny, the shirt soaks through, and when it tires drops
## now and then fly off its head.
class_name Model
extends Node3D

const HAIR_SHADER: Shader = preload("res://scenes/player/hair.gdshader")
const SWEAT_PATCHES_SHADER: Shader = preload("res://scenes/player/sweat_patches.gdshader")
## Match time (s) the player stays dry (about the first two or three games), and after which the
## sweat is full; in between it grows steadily.
const DRY_MATCH_TIME: float = 480.0
const FULL_SWEAT_MATCH_TIME: float = 5400.0
## Fully sweating: skin roughness and clearcoat (a wet film); the shirt soaks through in patches
## (see sweat_patches.gdshader).
const SWEAT_SKIN_ROUGHNESS: float = 0.25
const SWEAT_SKIN_CLEARCOAT: float = 0.6
## Sweat drops fly off in short bursts, only from a tired player (stamina below
## SWEAT_DROP_STAMINA) running: at most this many bursts per second (when exhausted, fully
## sweating and running at SWEAT_DROP_SPEED m/s or faster), each this long (s)
const SWEAT_DROP_STAMINA: float = 0.35
const SWEAT_DROP_SPEED: float = 5.0
const SWEAT_DROP_BURSTS: float = 0.6
const SWEAT_DROP_BURST_TIME: float = 0.3
## How fast (rad/s) the body turns
const BODY_TURN_SPEED: float = 10.0
## Bone the racket is held by (see the body's RacketAttachment)
const RACKET_GRIP_BONE: StringName = &"RacketGrip"
## Farthest (m) the racket reaches out of the swing for the ball; it reaches out over
## REACH_IN_TIME (s) before the `hit` marker and back over REACH_OUT_TIME after it.
const MAX_REACH: float = 0.45
const REACH_IN_TIME: float = 0.2
const REACH_OUT_TIME: float = 0.3
## The head turns toward what it looks at (and back) with this time constant (s)
const LOOK_FADE_TIME: float = 0.2
## Hand that holds and tosses the ball for a serve (see the body's TossAttachment)
const TOSS_HAND_BONE: StringName = &"LeftHand"

## Appearance every player's appearance builds on
@export var base_appearance: PlayerAppearance
@export var animator: PlayerAnimator
## Racket held in the right hand: moved onto the body's RacketAttachment, keeping its transform
## as the grip
@export var racket: Racket
## Sweat drops flying off the head: moved onto the body's HeadAttachment
@export var sweat_drops: GPUParticles3D
## The stroke animations the player swings
@export var stroke_clips: Array[StrokeClip] = []
## Ball held in the tossing hand before the serve: moved onto the body's TossAttachment
@export var held_ball: Node3D
## How far (m) the serve toss falls from its highest point before the racket meets it
@export_range(0.0, 1.0, 0.01, "suffix:m") var toss_drop: float = 0.35
## Lets the racket reach out of the swing for the ball around contact (see reach_toward); moved
## onto the body's skeleton
@export var arm_reach: RacketReachModifier
## Keeps the chest turned as in the stroke while the hips run with the legs; moved onto the body's
## skeleton
@export var torso_twist: TorsoTwistModifier
## Turns the head to look at look_target (see look_at_point); moved onto the body's skeleton
@export var head_look: LookAtModifier3D
@export var look_target: Marker3D

## The player's appearance merged onto the base appearance (see load_appearance)
var appearance: PlayerAppearance
## How much the player sweats, in [0, 1]
var sweat: float = 0.0
## World offset (m) the racket hand reaches by at contact (see reach_toward)
var reach: Vector3 = Vector3.ZERO

## Yaw (rad) of the body relative to the player's facing, in [-PI, PI]
var body_yaw: float = 0.0
## Where the racket's sweet spot meets the ball in each stroke clip, in model space with the body
## facing the player's facing (see get_contact_point)
var _contact_points: Dictionary[StrokeClip, Vector3] = {}
## Skeleton in model space with the body facing the player's facing, and the racket's sweet spot
## relative to the racket grip bone
var _skeleton_in_model: Transform3D
var _racket_sweet_spot: Vector3
## Body transform facing the player's facing
var _body_base_transform: Transform3D

## Point the head looks at, null for none (see look_at_point)
var _look_point: Variant = null
## Seconds left of the current burst of sweat drops
var _drop_burst_left: float = 0.0
## Skin material and its dry roughness, and the sweat patches drawn over the shirt
var _skin_material: StandardMaterial3D
var _dry_skin_roughness: float
var _sweat_patches: ShaderMaterial

@onready var _body: Node3D = $Body
@onready var _skeleton: Skeleton3D = _body.get_node("%GeneralSkeleton")


func _ready() -> void:
	_attach_to(_body)
	_body_base_transform = _body.transform
	set_body_yaw(0.0)
	for clip in stroke_clips:
		assert(
			animator.has_stroke_animation(clip.animation),
			"'%s' is not a stroke animation of the AnimationTree" % clip.animation
		)
		assert(
			animator.get_animation(clip.animation).has_marker(PlayerAnimator.HIT_MARKER),
			"'%s' has no 'hit' marker" % clip.animation
		)
	_find_contact_points()
	animator.mixer_applied.connect(_reach_with_swing)
	animator.mixer_applied.connect(_twist_torso_with_swing)


func _process(delta: float) -> void:
	var looking: bool = _look_point != null
	if looking:
		look_target.global_position = _look_point
	var follow: float = 1.0 - exp(-delta / LOOK_FADE_TIME)
	head_look.influence = lerpf(head_look.influence, 1.0 if looking else 0.0, follow)


## Shows `body` (an imported player body) instead of the scene's default body; none keeps the
## default.
func load_body(body: PackedScene) -> void:
	if body == null or body.resource_path == _body.scene_file_path:
		return
	var new_body: Node3D = body.instantiate()
	new_body.transform = _body.transform
	add_child(new_body)
	_attach_to(new_body)
	remove_child(_body)
	_body.free()
	new_body.name = &"Body"
	move_child(new_body, 0)
	_body = new_body
	_skeleton = new_body.get_node("%GeneralSkeleton")
	animator.clear_caches()
	_find_contact_points()


## Moves the racket, the sweat drops and the held ball onto the attachments of `body`, and the
## torso twist, the arm reach and the head look onto its skeleton (in this order of processing).
func _attach_to(body: Node3D) -> void:
	var skeleton: Skeleton3D = body.get_node("%GeneralSkeleton")
	racket.reparent(body.get_node("%RacketAttachment"), false)
	sweat_drops.reparent(body.get_node("%HeadAttachment"), false)
	held_ball.reparent(body.get_node("%TossAttachment"), false)
	torso_twist.reparent(skeleton, false)
	arm_reach.reparent(skeleton, false)
	head_look.reparent(skeleton, false)
	head_look.target_node = head_look.get_path_to(look_target)


## Turns the body toward `yaw` (rad, relative to the player's facing) the shorter way round, at
## BODY_TURN_SPEED.
func turn_body_toward(yaw: float, delta: float) -> void:
	var max_step: float = BODY_TURN_SPEED * delta
	set_body_yaw(body_yaw + clampf(wrapf(yaw - body_yaw, -PI, PI), -max_step, max_step))


func set_body_yaw(yaw: float) -> void:
	body_yaw = wrapf(yaw, -PI, PI)
	_body.transform = Transform3D(Basis(Vector3.UP, body_yaw)) * _body_base_transform


## Works out where the racket's sweet spot is at the `hit` marker of each stroke clip, for the
## current body.
func _find_contact_points() -> void:
	var yaw: float = body_yaw
	set_body_yaw(0.0)
	_skeleton_in_model = global_transform.affine_inverse() * _skeleton.global_transform
	set_body_yaw(yaw)
	_racket_sweet_spot = racket.transform * racket.sweet_spot.position
	arm_reach.sweet_spot = _racket_sweet_spot
	var grip: int = _skeleton.find_bone(RACKET_GRIP_BONE)
	for clip in stroke_clips:
		var animation: Animation = animator.get_animation(clip.animation)
		var hit_time: float = animation.get_marker_time(PlayerAnimator.HIT_MARKER)
		_contact_points[clip] = (
			_skeleton_in_model
			* ClipPose.bone_pose(animation, _skeleton, grip, hit_time)
			* _racket_sweet_spot
		)


## Swing that meets the ball of `stroke` at its contact height (or plays the first clip of its
## type without one): the two clips of its type whose contact heights lie around it, blended, or
## the lowest or highest clip for a ball below or above all of them.
func get_stroke_blend(stroke: Stroke) -> StrokeBlend:
	var clips: Array[StrokeClip] = stroke_clips.filter(
		func(clip: StrokeClip) -> bool: return clip.supports(stroke.stroke_type)
	)
	assert(not clips.is_empty(), "Model: no StrokeClip for stroke type %d" % stroke.stroke_type)
	if not stroke.step:
		return StrokeBlend.new(clips[0], clips[0], 0.0)
	clips.sort_custom(
		func(a: StrokeClip, b: StrokeClip) -> bool:
			return _contact_points[a].y < _contact_points[b].y
	)
	var height: float = stroke.step.point.y - global_position.y
	if height <= _contact_points[clips[0]].y:
		return StrokeBlend.new(clips[0], clips[0], 0.0)
	for i in range(1, clips.size()):
		var high_height: float = _contact_points[clips[i]].y
		if height <= high_height:
			var low_height: float = _contact_points[clips[i - 1]].y
			var weight: float = inverse_lerp(low_height, high_height, height)
			return StrokeBlend.new(clips[i - 1], clips[i], weight)
	return StrokeBlend.new(clips[-1], clips[-1], 0.0)


## World position where the racket meets the ball when the player swings `swing` facing its
## facing.
func get_contact_point(swing: StrokeBlend) -> Vector3:
	if swing.low == swing.high or swing.weight == 0.0:
		return global_transform * _contact_points[swing.low]
	if swing.weight == 1.0:
		return global_transform * _contact_points[swing.high]
	var low: Animation = animator.get_animation(swing.low.animation)
	var high: Animation = animator.get_animation(swing.high.animation)
	var grip: Transform3D = ClipPose.blended_bone_pose(
		low,
		low.get_marker_time(PlayerAnimator.HIT_MARKER),
		high,
		high.get_marker_time(PlayerAnimator.HIT_MARKER),
		swing.weight,
		_skeleton,
		_skeleton.find_bone(RACKET_GRIP_BONE)
	)
	return global_transform * _skeleton_in_model * grip * _racket_sweet_spot


## World position where the racket meets the ball for the given stroke.
func get_racket_contact_point(stroke: Stroke) -> Vector3:
	return get_contact_point(get_stroke_blend(stroke))


## Lets the racket hand reach out by `offset` (world, m; at most MAX_REACH) at the `hit` marker
## of the playing swing, to meet a ball the swing alone would miss.
func reach_toward(offset: Vector3) -> void:
	reach = offset.limit_length(MAX_REACH)
	arm_reach.reach = reach


## Turns the head toward `point` (world), or back to the animation for null.
func look_at_point(point: Variant) -> void:
	_look_point = point


## Turns the chest back to the stroke's turn as far as the hips run with the legs (see
## TorsoTwistModifier).
func _twist_torso_with_swing() -> void:
	var swing: StrokeBlend = animator.get_stroke()
	torso_twist.influence = animator.get_running_legs() if swing else 0.0
	if torso_twist.influence <= 0.0:
		return
	var clip_times: Vector2 = animator.get_stroke_clip_times()
	var hips: int = _skeleton.find_bone(TorsoTwistModifier.HIPS_BONE)
	torso_twist.stroke_hips = (
		ClipPose
		. blended_bone_pose(
			animator.get_animation(swing.low.animation),
			clip_times.x,
			animator.get_animation(swing.high.animation),
			clip_times.y,
			swing.weight,
			_skeleton,
			hips
		)
		. basis
		. get_rotation_quaternion()
	)


## Lets the racket reach out around the `hit` marker of the swing just applied.
func _reach_with_swing() -> void:
	var swing: StrokeBlend = animator.get_stroke()
	if not swing:
		arm_reach.influence = 0.0
		return
	var hit_time: float = animator.get_marker_time(swing, PlayerAnimator.HIT_MARKER)
	var time: float = animator.get_stroke_time()
	arm_reach.influence = (
		smoothstep(hit_time - REACH_IN_TIME, hit_time, time)
		if time <= hit_time
		else 1.0 - smoothstep(hit_time, hit_time + REACH_OUT_TIME, time)
	)


## Shows or hides the ball in the tossing hand.
func hold_ball(holding: bool) -> void:
	held_ball.visible = holding


## Tosses `ball` from the tossing hand, where it replaces the held ball: up so that it falls
## toss_drop from its highest point onto the contact point of the serve being played. Returns the
## seconds until it gets there.
func toss(ball: Ball) -> float:
	var release: Vector3 = held_ball.global_position
	var contact: Vector3 = get_contact_point(animator.get_stroke())
	var flight_time: float = _toss_flight_time(release, contact)
	ball.initial_position = release
	ball.initial_velocity = ball.velocity_to_reach(release, contact, flight_time)
	hold_ball(false)
	return flight_time


## Seconds until the racket meets the ball of the serve being played, before its toss: until the
## `toss` marker, and the flight of the toss from where the hand will be then.
func get_serve_seconds_to_contact() -> float:
	var serve: StrokeBlend = animator.get_stroke()
	var animation: Animation = animator.get_animation(serve.low.animation)
	var hand: Transform3D = ClipPose.bone_pose(
		animation,
		_skeleton,
		_skeleton.find_bone(TOSS_HAND_BONE),
		animation.get_marker_time(PlayerAnimator.TOSS_MARKER)
	)
	var release: Vector3 = global_transform * _skeleton_in_model * hand * held_ball.position
	return (
		animator.seconds_until_marker(PlayerAnimator.TOSS_MARKER)
		+ _toss_flight_time(release, get_contact_point(serve))
	)


## Pose of the model for a replay: the animation, the body's yaw and the racket's reach.
func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = animator.get_snapshot()
	snapshot["body_yaw"] = body_yaw
	snapshot["reach"] = reach
	return snapshot


## Reproduce a pose recorded with `get_snapshot` (used by replays).
func apply_snapshot(snapshot: Dictionary) -> void:
	set_body_yaw(snapshot["body_yaw"])
	reach_toward(snapshot["reach"])
	animator.apply_snapshot(snapshot)


## Seconds a toss from `release` takes to rise and fall toss_drop from its highest point onto
## `contact`.
func _toss_flight_time(release: Vector3, contact: Vector3) -> float:
	var rise: float = contact.y + toss_drop - release.y
	assert(rise > 0.0, "The toss is released above its highest point")
	return sqrt(2.0 * rise / Ball.GRAVITY) + sqrt(2.0 * toss_drop / Ball.GRAVITY)


## Shows the player's appearance on top of the base appearance.
func load_appearance(player_appearance: PlayerAppearance) -> void:
	appearance = player_appearance.merged_onto(base_appearance)
	_skin_material = _apply_look(&"Body", appearance.skin_texture, appearance.skin_color)
	var shirt_material: StandardMaterial3D = _apply_look(
		&"Shirt", appearance.shirt_texture, appearance.shirt_color
	)
	_apply_look(&"Shorts", appearance.shorts_texture, appearance.shorts_color)
	_apply_look(&"Shoes", appearance.shoes_texture, appearance.shoes_color)
	_apply_hair(appearance.hair_texture, appearance.hair_color)
	_dry_skin_roughness = _skin_material.roughness
	_skin_material.clearcoat_enabled = true
	_sweat_patches = ShaderMaterial.new()
	_sweat_patches.shader = SWEAT_PATCHES_SHADER
	shirt_material.next_pass = _sweat_patches
	set_sweat(sweat)


## Sweats as after `seconds` of match time.
func sweat_after_match_time(seconds: float) -> void:
	set_sweat(clampf(inverse_lerp(DRY_MATCH_TIME, FULL_SWEAT_MATCH_TIME, seconds), 0.0, 1.0))


## Sets how much the player sweats, in [0, 1].
func set_sweat(level: float) -> void:
	sweat = level
	_skin_material.roughness = lerpf(_dry_skin_roughness, SWEAT_SKIN_ROUGHNESS, sweat)
	_skin_material.clearcoat = SWEAT_SKIN_CLEARCOAT * sweat
	_sweat_patches.set_shader_parameter("sweat", sweat)


## Now and then sheds a burst of sweat drops while running at `speed` (m/s) tired
## (`stamina_ratio` low): more often the more tired, the sweatier and the faster.
func shed_sweat(speed: float, stamina_ratio: float, delta: float) -> void:
	_drop_burst_left -= delta
	if _drop_burst_left <= 0.0:
		var tiredness: float = clampf(
			inverse_lerp(SWEAT_DROP_STAMINA, 0.0, stamina_ratio), 0.0, 1.0
		)
		var rate: float = (
			SWEAT_DROP_BURSTS * tiredness * sweat * clampf(speed / SWEAT_DROP_SPEED, 0.0, 1.0)
		)
		if randf() < rate * delta:
			_drop_burst_left = SWEAT_DROP_BURST_TIME
	sweat_drops.emitting = _drop_burst_left > 0.0


## Mesh of the body in `slot`.
func _slot_mesh(slot: StringName) -> MeshInstance3D:
	var mesh: MeshInstance3D = _body.find_child(slot, true, false)
	assert(mesh != null, "The body %s has no %s mesh" % [_body.scene_file_path, slot])
	return mesh


## Gives the mesh in `slot` the texture (none for a plain color) tinted with `color`; returns its
## material.
func _apply_look(slot: StringName, texture: Texture2D, color: Color) -> StandardMaterial3D:
	var mesh: MeshInstance3D = _slot_mesh(slot)
	var base_material: Material = mesh.mesh.surface_get_material(0)
	var material: StandardMaterial3D = (
		(base_material as StandardMaterial3D).duplicate()
		if base_material is StandardMaterial3D
		else StandardMaterial3D.new()
	)
	material.albedo_texture = texture
	material.albedo_color = color
	mesh.set_surface_override_material(0, material)
	return material


func _apply_hair(texture: Texture2D, color: Color) -> void:
	var material := ShaderMaterial.new()
	material.shader = HAIR_SHADER
	material.set_shader_parameter("hair_texture", texture)
	material.set_shader_parameter("hair_color", color)
	_slot_mesh(&"Hair").material_override = material
