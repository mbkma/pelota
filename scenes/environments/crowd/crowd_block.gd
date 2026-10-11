@tool
class_name CrowdBlock
extends Node3D
## The spectators of one section of seats. All spectators of one character are drawn by one
## MultiMesh and animated on the GPU (see CrowdCharacter), so a block costs one draw call per
## character.

## Seconds over which the spectators of a cheer get up, so they do not all move at once
const CHEER_SPREAD: float = 0.4

var _config: CrowdConfig
var _multimeshes: Array[MultiMesh] = []


## Seats spectators in `seats` (see StadiumSeating) as `config` says, taking `occupancy` (0 to 1)
## of the seats; `seating_seed` decides who sits where, so the block looks the same every time.
func _init(
	config: CrowdConfig, seats: PackedVector4Array, occupancy: float, seating_seed: int
) -> void:
	_config = config
	var rng := RandomNumberGenerator.new()
	rng.seed = seating_seed
	var spectators: Array[Array] = []
	for character in config.characters:
		spectators.append([])
	for seat in seats:
		if rng.randf() >= occupancy:
			continue
		spectators[rng.randi() % config.characters.size()].append(_spectator(seat, rng))

	for i in config.characters.size():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = config.characters[i].mesh
		multimesh.instance_count = spectators[i].size()
		for instance in spectators[i].size():
			multimesh.set_instance_transform(instance, spectators[i][instance])
			multimesh.set_instance_custom_data(instance, _idle_data(rng))
		var instances := MultiMeshInstance3D.new()
		instances.multimesh = multimesh
		instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instances)
		_multimeshes.append(multimesh)


## Lets about `share` (0 to 1) of the spectators cheer, starting at `time` (s of the crowd's
## clock, see Crowd). Spectators still cheering finish their cheer: restarting it would make
## them jump.
func cheer(share: float, time: float) -> void:
	for i in _multimeshes.size():
		var multimesh: MultiMesh = _multimeshes[i]
		var clip_lengths: PackedFloat32Array = _config.characters[i].clip_lengths
		for instance in multimesh.instance_count:
			if randf() >= share:
				continue
			var data: Color = multimesh.get_instance_custom_data(instance)
			if data.g >= 0.0 and time < data.b + clip_lengths[int(data.g)]:
				continue
			data.g = Array(CrowdCharacter.CHEER_CLIPS).pick_random()
			data.b = time + randf() * CHEER_SPREAD
			multimesh.set_instance_custom_data(instance, data)


## Where a spectator sits on `seat`, a little shifted, turned and sized.
func _spectator(seat: Vector4, rng: RandomNumberGenerator) -> Transform3D:
	var offset: Vector3 = (
		_config.seat_offset + Vector3.RIGHT * rng.randf_range(-1.0, 1.0) * _config.seat_jitter
	)
	var turn: float = deg_to_rad(rng.randf_range(-1.0, 1.0) * _config.turn_jitter_degrees)
	var size: float = 1.0 + rng.randf_range(-1.0, 1.0) * _config.size_jitter
	var place: Transform3D = StadiumSeating.seat_transform(seat)
	return place * Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), offset)


## Instance data of a spectator idling: a random idle clip and look, no cheer (see crowd.gdshader).
static func _idle_data(rng: RandomNumberGenerator) -> Color:
	var idle_clips: PackedInt32Array = CrowdCharacter.IDLE_CLIPS
	return Color(idle_clips[rng.randi() % idle_clips.size()], -1.0, 0.0, rng.randf())
