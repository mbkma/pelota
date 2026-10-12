@tool
class_name CrowdBlock
extends Node3D
## The spectators of one block of seats. All spectators of one character are drawn by one
## MultiMesh and animated on the GPU (see CrowdCharacter), so a block costs one draw call per
## character. The level of detail is picked per block, by the distance to its nearest spectator,
## so blocks are kept to a few rows (see Crowd).

## Longest a spectator takes (s) to react to a point: most react at once, a few later, so they
## do not all move at once
const CHEER_REACTION_DELAY: float = 1.2
## Floats per spectator in a MultiMesh buffer: the transform's three rows, then the custom data
const INSTANCE_FLOATS: int = 16
const CUSTOM_OFFSET: int = 12

var _config: CrowdConfig
var _multimeshes: Array[MultiMesh] = []
var _instances: Array[MultiMeshInstance3D] = []
## The MultiMesh buffers as last sent, so a cheer changes the custom data without reading it back
## and sends each buffer once
var _buffers: Array[PackedFloat32Array] = []


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
		var buffer := PackedFloat32Array()
		buffer.resize(spectators[i].size() * INSTANCE_FLOATS)
		for instance in spectators[i].size():
			_write_instance(buffer, instance, spectators[i][instance], _idle_data(rng))
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.instance_count = spectators[i].size()
		multimesh.buffer = buffer
		var instances := MultiMeshInstance3D.new()
		instances.multimesh = multimesh
		instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instances)
		_multimeshes.append(multimesh)
		_instances.append(instances)
		_buffers.append(buffer)


## Draws the spectators of each character with its mesh in `meshes` (see CrowdCharacter.get_mesh),
## switching to its less detailed levels the sooner the lower `lod_bias` is (above 1 keeps more
## detail).
func set_detail(meshes: Array[ArrayMesh], lod_bias: float) -> void:
	for i in _instances.size():
		_multimeshes[i].mesh = meshes[i]
		_instances[i].lod_bias = lod_bias


## Lets about `share` (0 to 1) of the spectators cheer, each a random cheer, reacting from `time`
## (s of the crowd's clock, see Crowd) on. Spectators still cheering finish their cheer:
## restarting it would make them jump.
func cheer(share: float, time: float) -> void:
	var cheer_clips: Array = Array(CrowdCharacter.CHEER_CLIPS)
	for i in _multimeshes.size():
		var buffer: PackedFloat32Array = _buffers[i]
		var clip_lengths: PackedFloat32Array = _config.characters[i].clip_lengths
		var changed: bool = false
		for instance in _multimeshes[i].instance_count:
			if randf() >= share:
				continue
			var custom: int = instance * INSTANCE_FLOATS + CUSTOM_OFFSET
			var cheer_clip: int = int(buffer[custom + 1])
			if cheer_clip >= 0:
				var tempo: float = CrowdCharacter.cheer_tempo(buffer[custom + 3])
				if time < buffer[custom + 2] + clip_lengths[cheer_clip] / tempo:
					continue
			buffer[custom + 1] = cheer_clips.pick_random()
			buffer[custom + 2] = time + pow(randf(), 2.0) * CHEER_REACTION_DELAY
			changed = true
		if changed:
			_multimeshes[i].buffer = buffer


## Where a spectator sits on `seat`, a little shifted, turned and sized.
func _spectator(seat: Vector4, rng: RandomNumberGenerator) -> Transform3D:
	var offset: Vector3 = (
		_config.seat_offset + Vector3.RIGHT * rng.randf_range(-1.0, 1.0) * _config.seat_jitter
	)
	var turn: float = deg_to_rad(rng.randf_range(-1.0, 1.0) * _config.turn_jitter_degrees)
	var size: float = 1.0 + rng.randf_range(-1.0, 1.0) * _config.size_jitter
	var place: Transform3D = StadiumSeating.seat_transform(seat)
	return place * Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), offset)


## Writes the transform (row by row) and custom data of `instance` into a MultiMesh `buffer`.
static func _write_instance(
	buffer: PackedFloat32Array, instance: int, place: Transform3D, data: Color
) -> void:
	var start: int = instance * INSTANCE_FLOATS
	for row in 3:
		buffer[start + row * 4] = place.basis.x[row]
		buffer[start + row * 4 + 1] = place.basis.y[row]
		buffer[start + row * 4 + 2] = place.basis.z[row]
		buffer[start + row * 4 + 3] = place.origin[row]
	for i in 4:
		buffer[start + CUSTOM_OFFSET + i] = data[i]


## Instance data of a spectator idling: a random idle clip and look, no cheer (see crowd.gdshader).
static func _idle_data(rng: RandomNumberGenerator) -> Color:
	var idle_clips: PackedInt32Array = CrowdCharacter.IDLE_CLIPS
	return Color(idle_clips[rng.randi() % idle_clips.size()], -1.0, 0.0, rng.randf())
