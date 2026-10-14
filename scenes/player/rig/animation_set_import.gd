## The animations of an imported animation set the player uses, and where they are saved (see
## player_animations_import.gd).
class_name AnimationSetImport
extends Resource

## Folder the animations are saved in, each as <name>.tres
@export_dir var output_dir: String
@export var clips: Array[AnimationClipImport] = []
