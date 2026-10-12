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


## Tempo a spectator with the random `look` (see crowd.gdshader) cheers at, the same as in the
## crowd shader.
static func cheer_tempo(look: float) -> float:
	return lerpf(CHEER_TEMPO.x, CHEER_TEMPO.y, fposmod(look * 13.0, 1.0))


## The crowd shader material of the mesh; the crowd sets its time.
func get_material() -> ShaderMaterial:
	return mesh.surface_get_material(0)
