class_name CrowdCharacter
extends Resource
## A spectator model baked for the crowd (see CrowdBaker): one mesh with all its parts in one
## texture atlas, and its animations baked into a bone texture, so that whole blocks of spectators
## are drawn with one MultiMesh and animated on the GPU by the crowd shader.

## Clips of every character, in the order of the bone texture: sitting idles, then cheers
const IDLE_CLIPS: PackedInt32Array = [0, 1, 2]
const CHEER_CLIPS: PackedInt32Array = [3, 4, 5]

## The spectator: all parts in one surface with its crowd shader material. Its vertices carry the
## skeleton bones (CUSTOM0) and their weights (CUSTOM1), and the part they belong to (UV2.x, see
## CrowdBaker.Part) for the clothes colors.
@export var mesh: ArrayMesh
## Lengths (s) of the clips
@export var clip_lengths: PackedFloat32Array = []


## The crowd shader material of the mesh; the crowd sets its time.
func get_material() -> ShaderMaterial:
	return mesh.surface_get_material(0)
