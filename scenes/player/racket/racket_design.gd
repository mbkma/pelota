## A racket a player plays with: its brand and model, and the textures of its frame and strings
## (see Racket). The player's bench shows it too, with a bag of the brand (see TennisBag).
class_name RacketDesign
extends Resource

enum Brand { HEAD, TECNIFIBRE, WILSON, BABOLAT, YONEX, DUNLOP, DIADEM }

@export var brand: Brand = Brand.HEAD
## Model as printed on the frame
@export var model: String = ""
@export var frame_texture: Texture2D
@export var strings_texture: Texture2D
