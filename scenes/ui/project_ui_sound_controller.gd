## The UI sounds of the whole game (see the ProjectUISoundController autoload). The sounds of the
## UI set differ much in loudness, so each is played at its own volume: the hover and drag sounds
## are quietest, then the tab change and the item picks, the button press is the clearest.
class_name ProjectUiSoundController
extends UISoundController

## Volume (dB) per sound, by the name of its export in UISoundController
@export var volumes_db: Dictionary[StringName, float] = {}


func _ready() -> void:
	super._ready()
	for sound in volumes_db:
		var player: AudioStreamPlayer = get(String(sound) + "_player")
		player.volume_db = volumes_db[sound]
