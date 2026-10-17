## The materials a builder (see ArthurAsheBuilder) gives its meshes, saved as resources in one
## folder so they can be edited in the editor: the meshes refer to them, and changes show without
## building again.
class_name MaterialLibrary
extends RefCounted


## The materials (.tres) in `folder`, by file name.
static func load_folder(folder: String) -> Dictionary[String, Material]:
	var materials: Dictionary[String, Material] = {}
	for file: String in ResourceLoader.list_directory(folder):
		if file.get_extension() == "tres":
			materials[file.get_basename()] = load(folder.path_join(file))
	assert(not materials.is_empty(), "No materials in %s" % folder)
	return materials
