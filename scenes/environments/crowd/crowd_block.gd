@tool
class_name CrowdBlock
extends Node3D
## A grid of seats filled with spectators by its config. All spectators of one character are
## drawn by one MultiMesh and animated on the GPU (see CrowdCharacter), so a block costs one draw
## call per character. In the editor the block is rebuilt whenever the config changes.

## Seconds over which the spectators of a cheer get up, so they do not all move at once
const CHEER_SPREAD: float = 0.4

@export var config: CrowdConfig:
	set(value):
		if config and config.changed.is_connected(_rebuild):
			config.changed.disconnect(_rebuild)
		config = value
		if Engine.is_editor_hint() and config:
			config.changed.connect(_rebuild)
			_rebuild.call_deferred()
## Seed of who sits where, so the block looks the same every time
@export var seating_seed: int = 0:
	set(value):
		seating_seed = value
		if Engine.is_editor_hint() and is_inside_tree():
			_rebuild.call_deferred()

var _multimeshes: Array[MultiMesh] = []


func _ready() -> void:
	_rebuild()


## Lets about `share` (0 to 1) of the spectators cheer, starting at `time` (s of the crowd's
## clock, see Crowd). Spectators still cheering finish their cheer: restarting it would make
## them jump.
func cheer(share: float, time: float) -> void:
	for i in _multimeshes.size():
		var multimesh: MultiMesh = _multimeshes[i]
		var clip_lengths: PackedFloat32Array = config.characters[i].clip_lengths
		for instance in multimesh.instance_count:
			if randf() >= share:
				continue
			var data: Color = multimesh.get_instance_custom_data(instance)
			if data.g >= 0.0 and time < data.b + clip_lengths[int(data.g)]:
				continue
			data.g = Array(CrowdCharacter.CHEER_CLIPS).pick_random()
			data.b = time + randf() * CHEER_SPREAD
			multimesh.set_instance_custom_data(instance, data)


func _rebuild() -> void:
	for child in get_children():
		if child is MultiMeshInstance3D:
			child.free()
	_multimeshes.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seating_seed
	var seats: Array[Array] = []
	for character in config.characters:
		seats.append([])
	for row in config.grid_rows:
		for column in config.grid_columns:
			if rng.randf() >= config.occupancy:
				continue
			seats[rng.randi() % config.characters.size()].append(_seat(row, column, rng))

	for i in config.characters.size():
		var character: CrowdCharacter = config.characters[i]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = character.mesh
		multimesh.instance_count = seats[i].size()
		for instance in seats[i].size():
			multimesh.set_instance_transform(instance, seats[i][instance])
			multimesh.set_instance_custom_data(instance, _idle_data(rng))
		var spectators := MultiMeshInstance3D.new()
		spectators.multimesh = multimesh
		spectators.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spectators)
		_multimeshes.append(multimesh)


## Where a spectator sits in the seat at `row` and `column`, a little shifted, turned and sized.
func _seat(row: int, column: int, rng: RandomNumberGenerator) -> Transform3D:
	var position := Vector3(
		column * config.seat_spacing.x + rng.randf_range(-1.0, 1.0) * config.seat_jitter,
		row * config.seat_spacing.y,
		-row * config.seat_spacing.z
	)
	var turn: float = deg_to_rad(rng.randf_range(-1.0, 1.0) * config.turn_jitter_degrees)
	var size: float = 1.0 + rng.randf_range(-1.0, 1.0) * config.size_jitter
	return Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), position)


## Instance data of a spectator idling: a random idle clip and look, no cheer (see crowd.gdshader).
static func _idle_data(rng: RandomNumberGenerator) -> Color:
	var idle_clips: PackedInt32Array = CrowdCharacter.IDLE_CLIPS
	return Color(idle_clips[rng.randi() % idle_clips.size()], -1.0, 0.0, rng.randf())
