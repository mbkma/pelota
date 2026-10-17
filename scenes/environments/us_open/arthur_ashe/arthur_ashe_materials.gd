class_name ArthurAsheMaterials
extends RefCounted
## Materials of Arthur Ashe Stadium and its courtside props (see ArthurAsheBuilder), saved in
## FOLDER. Most take their color from the vertex colors too, which vary the surfaces' gray
## levels a little, and lay their textures out by the world position (triplanar), as the
## builders' meshes have no UVs.

const FOLDER: String = "res://scenes/environments/us_open/materials/"


## The stadium's materials by name.
static func make() -> Dictionary[String, Material]:
	return MaterialLibrary.load_folder(FOLDER)
