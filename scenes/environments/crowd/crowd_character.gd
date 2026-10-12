class_name CrowdCharacter
extends Resource
## A spectator model baked for the crowd (see CrowdBaker): one mesh with all its parts in one
## texture atlas, and its animations baked into a bone texture, so that whole blocks of spectators
## are drawn with one MultiMesh and animated on the GPU by the crowd shader.

## Clips of every character, in the order of the bone texture: sitting idles, then cheers, then
## the same cheers mirrored (see CrowdBaker.MIRRORED_CLIPS)
const IDLE_CLIPS: PackedInt32Array = [0, 1, 2]
const CHEER_CLIPS: PackedInt32Array = [3, 4, 5, 6, 7, 8]
## Slowest and fastest tempo a spectator cheers at, so that spectators cheering the same clip do
## not move in step (the same as in crowd.gdshader)
const CHEER_TEMPO := Vector2(0.85, 1.15)

## The spectator: all parts in one surface with its crowd shader material. Its vertices carry the
## skeleton bones (CUSTOM0) and their weights (CUSTOM1), and the part they belong to (UV2.x, see
## CrowdBaker.Part) for the clothes colors.
@export var mesh: ArrayMesh
## Lengths (s) of the clips
@export var clip_lengths: PackedFloat32Array = []

## Copies of the mesh without its most detailed levels, by the most triangles they keep
var _capped_meshes: Dictionary[int, ArrayMesh] = {}


## Vertex format flags of the mesh's surface: bones and weights as four floats each.
static func custom_format_flags() -> int:
	return (
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	)


## Tempo a spectator with the random `look` (see crowd.gdshader) cheers at, the same as in the
## crowd shader.
static func cheer_tempo(look: float) -> float:
	return lerpf(CHEER_TEMPO.x, CHEER_TEMPO.y, fposmod(look * 13.0, 1.0))


## The crowd shader material of the mesh; the crowd sets its time.
func get_material() -> ShaderMaterial:
	return mesh.surface_get_material(0)


## The mesh without the levels of detail (see Mesh LOD) that have more than `max_triangles`: its
## most detailed level is the most detailed one with at most `max_triangles` (the least detailed
## one if none has), 0 for the full mesh. In a crowd even the nearest spectators look the same
## with a fraction of the triangles of the full mesh, which costs the GPU most of a frame. The
## characters' levels differ, so they are picked by triangles rather than by level.
func get_mesh(max_triangles: int) -> ArrayMesh:
	if max_triangles <= 0:
		return mesh
	if not _capped_meshes.has(max_triangles):
		_capped_meshes[max_triangles] = _capped_mesh(max_triangles)
	return _capped_meshes[max_triangles]


func _capped_mesh(max_triangles: int) -> ArrayMesh:
	var surface: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var lods: Array = surface.get("lods", [])
	var index_size: int = 4 if surface["vertex_count"] > 0xFFFF else 2
	if surface["index_count"] / 3 <= max_triangles or lods.is_empty():
		return mesh
	# Number of levels left out: the first level with at most max_triangles is the new full mesh.
	var skipped: int = lods.size()
	for i in lods.size():
		if lods[i]["index_data"].size() / index_size / 3 <= max_triangles:
			skipped = i + 1
			break
	var arrays: Array = mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_INDEX] = _indices(lods[skipped - 1]["index_data"], index_size)
	var less_detailed: Dictionary = {}
	for lod in lods.slice(skipped):
		less_detailed[lod["edge_length"]] = _indices(lod["index_data"], index_size)
	var capped := ArrayMesh.new()
	capped.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES, arrays, [], less_detailed, custom_format_flags()
	)
	capped.surface_set_material(0, mesh.surface_get_material(0))
	capped.custom_aabb = mesh.custom_aabb
	return capped


## Indices of a level of detail as the rendering server keeps them: `size` bytes each.
static func _indices(data: PackedByteArray, size: int) -> PackedInt32Array:
	if size == 4:
		return data.to_int32_array()
	var indices := PackedInt32Array()
	indices.resize(data.size() / 2)
	for i in indices.size():
		indices[i] = data.decode_u16(i * 2)
	return indices
