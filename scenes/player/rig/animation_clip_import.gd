## How one animation of an imported animation set is saved for the player (see
## player_animations_import.gd).
class_name AnimationClipImport
extends Resource

## Name of the animation in the imported file
@export var source: StringName
## Name the animation is saved under, as the player's AnimationLibrary and AnimationTree use it
@export var name: StringName
@export var loop: bool = false
## Markers (s) the game times the clip by: `hit` (racket meets the ball), `toss` (serve toss
## released), `swing` (racket at its farthest back, the forward swing starts)
@export var markers: Dictionary[StringName, float] = {}
