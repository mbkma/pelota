## Bakes the crowd characters from the retargeted Mixamo sources in SOURCE_DIR into
## CrowdCharacter resources in OUTPUT_DIR. Run it after changing a source:
##
##     godot --headless --path . -s res://scenes/environments/crowd/baker/crowd_baker.gd
##
## For each character it
## - merges all meshes into one surface whose textures share one atlas (ATLAS_SIZE), and marks
##   each vertex with the part it belongs to (for the clothes colors);
## - moves the vertices into the skeleton's rest pose and keeps their four strongest bones;
## - generates levels of detail;
## - plays every clip on the retargeted skeleton and stores each bone's skinning matrix per frame
##   (FRAME_RATE) in a float texture, which the crowd shader animates the vertices with.
class_name CrowdBaker
extends SceneTree

## Part of a spectator a vertex belongs to (stored in UV2.x)
enum Part {
	SKIN,
	TOP,
	BOTTOM,
	SHOES,
	HAIR,
}

const SOURCE_DIR: String = "res://assets/models/crowd/source/"
const OUTPUT_DIR: String = "res://scenes/environments/crowd/characters/"
const CHARACTER_COUNT: int = 6
## Clips in the order of CrowdCharacter.IDLE_CLIPS and CHEER_CLIPS
const CLIPS: PackedStringArray = [
	"sit_idle_1", "sit_idle_2", "sit_idle_3", "sit_cheer_1", "sit_cheer_2", "sit_cheer_3"
]
const SOURCE_ANIMATION: StringName = &"mixamo_com"
const FRAME_RATE: float = 30.0
## Size (px) of a character's texture atlas, and the gap (px) kept around each texture in it
const ATLAS_SIZE: int = 1024
const ATLAS_PADDING: int = 4
const CROWD_SHADER: Shader = preload("res://scenes/environments/crowd/crowd.gdshader")
## Words in a mesh's name that tell its part
const TOP_WORDS: PackedStringArray = ["shirt", "top", "hoodie", "sweater", "collar", "jacket"]
const BOTTOM_WORDS: PackedStringArray = ["pants", "bottom", "shorts", "skirt"]
const SHOES_WORDS: PackedStringArray = ["shoe", "sneaker"]
const HAIR_WORDS: PackedStringArray = ["hair", "beard"]
## Standing height (m) every character is scaled to; the crowd blocks vary it a little
const STANDING_HEIGHT: float = 1.75
## Margin (m) around the rest pose's bounds, so animated spectators (arms up when cheering) are
## not culled while still on screen
const BOUNDS_MARGIN: float = 0.6
## Angle (degrees) within which the level of detail generation merges normals
const LOD_NORMAL_MERGE_ANGLE: float = 25.0
const LOD_NORMAL_SPLIT_ANGLE: float = 60.0


func _initialize() -> void:
	# The models have to be in the running tree to be posed.
	_bake_all.call_deferred()


func _bake_all() -> void:
	var clips: Array[Animation] = []
	for clip in CLIPS:
		var scene: Node = (load(SOURCE_DIR + clip + ".fbx") as PackedScene).instantiate()
		var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		clips.append(player.get_animation(SOURCE_ANIMATION))
		scene.free()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	for index in range(1, CHARACTER_COUNT + 1):
		var character: CrowdCharacter = _bake_character(
			SOURCE_DIR + "crowd_character_%d.fbx" % index, clips
		)
		var path: String = OUTPUT_DIR + "crowd_character_%d.res" % index
		var error: Error = ResourceSaver.save(character, path)
		assert(error == OK, "Could not save %s: %s" % [path, error_string(error)])
		print("baked ", path)
	quit()


func _bake_character(source: String, clips: Array[Animation]) -> CrowdCharacter:
	var model: Node3D = (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var skeleton: Skeleton3D = model.find_child("GeneralSkeleton", true, false)
	skeleton.reset_bone_poses()
	var mesh_instances: Array[MeshInstance3D] = []
	for node in skeleton.find_children("*", "MeshInstance3D", true, false):
		mesh_instances.append(node)
	var atlas := _Atlas.new(mesh_instances)

	# Skeleton space to the model's, scaled to the standing height (the sources differ in scale).
	var to_model: Transform3D = model.global_transform.affine_inverse() * skeleton.global_transform
	var arrays: Array = _merged_arrays(mesh_instances, skeleton, to_model, atlas)
	var height: float = _height(arrays[Mesh.ARRAY_VERTEX])
	to_model = Transform3D(Basis.from_scale(Vector3.ONE * STANDING_HEIGHT / height)) * to_model
	arrays = _merged_arrays(mesh_instances, skeleton, to_model, atlas)

	var character := CrowdCharacter.new()
	var material := ShaderMaterial.new()
	material.shader = CROWD_SHADER
	material.set_shader_parameter("atlas", atlas.compressed_texture())
	var bone_texture: ImageTexture = _bone_texture(model, skeleton, to_model, clips, character)
	material.set_shader_parameter("bone_texture", bone_texture)
	# The shader takes the frame counts as baked, not from the lengths: float rounding there
	# could count a frame more and show the next clip's first frame.
	var starts := PackedFloat32Array()
	var frames := PackedFloat32Array()
	for clip in clips:
		starts.append(_sum(frames))
		frames.append(_frame_count(clip.length))
	material.set_shader_parameter("clip_start", starts)
	material.set_shader_parameter("clip_frames", frames)
	material.set_shader_parameter("clip_length", character.clip_lengths)

	var importer := ImporterMesh.new()
	importer.add_surface(
		Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, material, "crowd", _custom_format_flags()
	)
	importer.generate_lods(LOD_NORMAL_MERGE_ANGLE, LOD_NORMAL_SPLIT_ANGLE, [])
	character.mesh = importer.get_mesh()
	character.mesh.custom_aabb = character.mesh.get_aabb().grow(BOUNDS_MARGIN)
	model.free()
	return character


## Height (m) of `vertices` from the lowest to the highest.
static func _height(vertices: PackedVector3Array) -> float:
	var lowest: float = INF
	var highest: float = -INF
	for vertex in vertices:
		lowest = minf(lowest, vertex.y)
		highest = maxf(highest, vertex.y)
	return highest - lowest


## Vertex format flags of the merged surface: bones and weights as four floats each.
static func _custom_format_flags() -> int:
	return (
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	)


## All surfaces of `mesh_instances` in one, in the model's space and the skeleton's rest pose,
## with atlas UVs, skeleton bones and weights (four per vertex) and parts.
func _merged_arrays(
	mesh_instances: Array[MeshInstance3D],
	skeleton: Skeleton3D,
	to_model: Transform3D,
	atlas: _Atlas
) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var parts := PackedVector2Array()
	var bones := PackedFloat32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	for mesh_instance in mesh_instances:
		var skin_bones: PackedInt32Array = _skin_bones(mesh_instance.skin, skeleton)
		var part: Part = _part(mesh_instance.name)
		for surface in mesh_instance.mesh.get_surface_count():
			var source: Array = mesh_instance.mesh.surface_get_arrays(surface)
			var texture: Texture2D = atlas.surface_texture(mesh_instance, surface)
			var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
			var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
			var source_uvs: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
			var source_bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
			var source_weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
			var influences: int = floori(float(source_bones.size()) / source_vertices.size())
			var offset: int = vertices.size()
			for vertex in source_vertices.size():
				var strongest: Array[Vector2] = _strongest_influences(
					source_bones, source_weights, vertex, influences
				)
				# Skinned to the rest pose: the weighted sum of the bones' rest skinning.
				var axes: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
				var origin := Vector3.ZERO
				for influence in strongest:
					var bind: int = int(influence.x)
					var rest: Transform3D = (
						skeleton.get_bone_global_rest(skin_bones[bind])
						* mesh_instance.skin.get_bind_pose(bind)
					)
					for axis in 3:
						axes[axis] += rest.basis[axis] * influence.y
					origin += rest.origin * influence.y
				var total := Transform3D(Basis(axes[0], axes[1], axes[2]), origin)
				vertices.append(to_model * (total * source_vertices[vertex]))
				normals.append((to_model.basis * total.basis * source_normals[vertex]).normalized())
				uvs.append(atlas.atlas_uv(texture, source_uvs[vertex]))
				parts.append(Vector2(part, 0.0))
				for i in 4:
					if i < strongest.size():
						bones.append(skin_bones[int(strongest[i].x)])
						weights.append(strongest[i].y)
					else:
						bones.append(0.0)
						weights.append(0.0)
			for index in source[Mesh.ARRAY_INDEX]:
				indices.append(offset + index)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = parts
	arrays[Mesh.ARRAY_CUSTOM0] = bones
	arrays[Mesh.ARRAY_CUSTOM1] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## The four strongest (bind, weight) influences of `vertex`, weights normalized.
static func _strongest_influences(
	bones: PackedInt32Array, weights: PackedFloat32Array, vertex: int, influences: int
) -> Array[Vector2]:
	var all: Array[Vector2] = []
	for i in influences:
		var weight: float = weights[vertex * influences + i]
		if weight > 0.0:
			all.append(Vector2(bones[vertex * influences + i], weight))
	all.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	all = all.slice(0, 4)
	var total: float = 0.0
	for influence in all:
		total += influence.y
	for i in all.size():
		all[i].y /= total
	return all


## Skeleton bone of each bind of `skin`.
static func _skin_bones(skin: Skin, skeleton: Skeleton3D) -> PackedInt32Array:
	var bones := PackedInt32Array()
	for bind in skin.get_bind_count():
		var bone: int = skin.get_bind_bone(bind)
		if bone == -1:
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		assert(bone != -1, "Skin bind %d has no bone in the skeleton" % bind)
		bones.append(bone)
	return bones


## Part of a mesh by the words in its name; the skin (body, eyes, lashes) when none matches.
static func _part(mesh_name: String) -> Part:
	var lower: String = mesh_name.to_lower()
	if _contains_any(lower, TOP_WORDS):
		return Part.TOP
	if _contains_any(lower, BOTTOM_WORDS):
		return Part.BOTTOM
	if _contains_any(lower, SHOES_WORDS):
		return Part.SHOES
	if _contains_any(lower, HAIR_WORDS):
		return Part.HAIR
	return Part.SKIN


static func _contains_any(text: String, words: PackedStringArray) -> bool:
	for word in words:
		if word in text:
			return true
	return false


## Skinning matrix of every bone at every frame of every clip, three texels per bone (the rows of
## its 3x4 matrix in the model's space), one texture row per frame. Fills the clip lengths of
## `character`.
func _bone_texture(
	model: Node3D,
	skeleton: Skeleton3D,
	to_model: Transform3D,
	clips: Array[Animation],
	character: CrowdCharacter
) -> ImageTexture:
	var library := AnimationLibrary.new()
	var total_frames: int = 0
	for i in clips.size():
		library.add_animation(CLIPS[i], clips[i])
		character.clip_lengths.append(clips[i].length)
		total_frames += _frame_count(clips[i].length)
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"", library)

	var rest_inverse: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		rest_inverse.append(skeleton.get_bone_global_rest(bone).affine_inverse())
	var image := Image.create_empty(
		skeleton.get_bone_count() * 3, total_frames, false, Image.FORMAT_RGBAF
	)
	var row: int = 0
	for i in clips.size():
		player.play(CLIPS[i])
		for frame in _frame_count(clips[i].length):
			skeleton.reset_bone_poses()
			player.seek(frame / FRAME_RATE, true)
			for bone in skeleton.get_bone_count():
				var skinning: Transform3D = (
					to_model
					* skeleton.get_bone_global_pose(bone)
					* rest_inverse[bone]
					* to_model.affine_inverse()
				)
				var basis: Basis = skinning.basis
				var origin: Vector3 = skinning.origin
				image.set_pixel(bone * 3, row, Color(basis.x.x, basis.y.x, basis.z.x, origin.x))
				image.set_pixel(bone * 3 + 1, row, Color(basis.x.y, basis.y.y, basis.z.y, origin.y))
				image.set_pixel(bone * 3 + 2, row, Color(basis.x.z, basis.y.z, basis.z.z, origin.z))
			row += 1
	return ImageTexture.create_from_image(image)


static func _sum(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for value in values:
		total += value
	return total


## Frames of a clip `length` seconds long, both ends included.
static func _frame_count(length: float) -> int:
	return floori(length * FRAME_RATE) + 1


## The textures of a character packed into one atlas: a grid of equal tiles.
class _Atlas:
	var _tiles: Dictionary[Texture2D, Rect2i] = {}
	var _image: Image

	func _init(mesh_instances: Array[MeshInstance3D]) -> void:
		var textures: Array[Texture2D] = []
		var colors: Dictionary[Texture2D, Color] = {}
		for mesh_instance in mesh_instances:
			for surface in mesh_instance.mesh.get_surface_count():
				var material: StandardMaterial3D = _material(mesh_instance, surface)
				if not textures.has(material.albedo_texture):
					textures.append(material.albedo_texture)
					colors[material.albedo_texture] = material.albedo_color
		var grid: int = ceili(sqrt(textures.size()))
		var tile: int = floori(float(ATLAS_SIZE) / grid)
		_image = Image.create_empty(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
		for i in textures.size():
			var cell := Rect2i(
				(i % grid) * tile + ATLAS_PADDING,
				floori(float(i) / grid) * tile + ATLAS_PADDING,
				tile - 2 * ATLAS_PADDING,
				tile - 2 * ATLAS_PADDING
			)
			var source: Image = textures[i].get_image()
			source.decompress()
			source.convert(Image.FORMAT_RGBA8)
			source.resize(cell.size.x, cell.size.y, Image.INTERPOLATE_LANCZOS)
			var color: Color = colors[textures[i]]
			for y in cell.size.y:
				for x in cell.size.x:
					source.set_pixel(x, y, source.get_pixel(x, y) * color)
			_image.blit_rect(source, Rect2i(Vector2i.ZERO, cell.size), cell.position)
			_tiles[textures[i]] = cell

	func surface_texture(mesh_instance: MeshInstance3D, surface: int) -> Texture2D:
		return _material(mesh_instance, surface).albedo_texture

	## UV in the atlas of `uv` on `texture`.
	func atlas_uv(texture: Texture2D, uv: Vector2) -> Vector2:
		var cell: Rect2i = _tiles[texture]
		var inside := Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
		return (Vector2(cell.position) + inside * Vector2(cell.size)) / float(ATLAS_SIZE)

	## The atlas, compressed for the GPU, with mipmaps.
	func compressed_texture() -> ImageTexture:
		var image: Image = _image.duplicate()
		image.generate_mipmaps()
		image.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_SRGB)
		return ImageTexture.create_from_image(image)

	static func _material(mesh_instance: MeshInstance3D, surface: int) -> StandardMaterial3D:
		return mesh_instance.mesh.surface_get_material(surface)
