## Builds the meshes of the stadium's courtside props into MESH_DIR. Run it after changing it:
##
##     godot --headless --path . \
##         -s res://scenes/environments/us_open/props/courtside_props_builder.gd
##
## The props are scenes placed by hand in the stadium scene, so they can be moved, turned and
## copied in the editor; this only makes their meshes, and running it again keeps where they are.
## Every prop faces the court along its +Z and stands on the floor at its origin:
## - the players' benches: a mat with the Polo pony, a navy Polo box, a white chair;
## - folded towels and one hanging over a chair's back, water bottles, tennis bags (colored per
##   brand, see TennisBag);
## - a photographer's place (a stool and a camera with a long white lens on a monopod) and a TV
##   camera operator's stool; the photographers and operators themselves are crowd people.
class_name CourtsidePropsBuilder
extends SceneTree

const MESH_DIR: String = "res://scenes/environments/us_open/props/meshes/"
## Tennis bag: length, width and height (m), and the depth of the end panels
const BAG_SIZE: Vector3 = Vector3(0.78, 0.33, 0.3)
## Water bottle: radius and height of the body (m)
const BOTTLE_SIZE: Vector2 = Vector2(0.034, 0.2)
## Facets of round props
const ROUND_SIDES: int = 10

var _materials: Dictionary[String, Material] = ArthurAsheMaterials.make()


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	DirAccess.make_dir_recursive_absolute(MESH_DIR)
	_save("bench_mat", _bench_mat())
	_save("bench_box", _bench_box())
	_save("bench_chair", _bench_chair())
	_save("towel", _towel())
	_save("hanging_towel", _hanging_towel())
	_save("water_bottle", _water_bottle())
	_save("tennis_bag", _tennis_bag())
	_save("photographer", _photographer())
	_save("operator_stool", _operator_stool())
	quit()


func _save(mesh_name: String, geometry: FlatGeometry) -> void:
	var path: String = MESH_DIR + mesh_name + ".res"
	var error: Error = ResourceSaver.save(geometry.to_mesh(), path, ResourceSaver.FLAG_COMPRESS)
	assert(error == OK, "Could not save %s: %s" % [path, error_string(error)])
	print("saved ", path)


## A navy mat under the bench, 3.3 m along the court, with the Polo pony at both ends.
func _bench_mat() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	geometry.box(
		_materials["mat"],
		Transform3D(Basis(), Vector3(0.0, 0.006, 0.0)),
		Vector3(3.3, 0.012, 1.4),
		Color(0.6, 0.6, 0.65)
	)
	for x: float in [-1.35, 1.35]:
		UsOpenLogos.add_flat(
			geometry,
			_materials["logos"],
			&"polo_pony",
			Vector3(x, 0.013, 0.0),
			Vector3.FORWARD,
			0.4
		)
	return geometry


## The navy box the spare rackets lean against, POLO on its front and ends.
func _bench_box() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var size := Vector3(1.6, 0.46, 0.54)
	var center := Vector3(0.0, size.y * 0.5, 0.0)
	geometry.box(_materials["fascia"], Transform3D(Basis(), center), size)
	for face: Vector3 in [Vector3.BACK, Vector3.RIGHT, Vector3.LEFT]:
		var offset: Vector3 = face * (size * 0.5 + Vector3.ONE * 0.003)
		UsOpenLogos.add(
			geometry, _materials["logos"], &"polo", center + offset + Vector3.UP * 0.05, face, 0.12
		)
	return geometry


## The player's white chair.
func _bench_chair() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var white: Material = _materials["white"]
	geometry.box(white, Transform3D(Basis(), Vector3(0.0, 0.45, 0.0)), Vector3(0.5, 0.06, 0.5))
	geometry.box(
		white,
		Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0.0, 0.78, -0.27)),
		Vector3(0.5, 0.62, 0.05)
	)
	for x: float in [-0.23, 0.23]:
		geometry.box(white, Transform3D(Basis(), Vector3(x, 0.22, 0.0)), Vector3(0.04, 0.44, 0.5))
	return geometry


## A folded towel, the US Open logo on top.
func _towel() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	geometry.box(
		_materials["towel"],
		Transform3D(Basis(), Vector3(0.0, 0.035, 0.0)),
		Vector3(0.5, 0.07, 0.42)
	)
	UsOpenLogos.add_flat(
		geometry, _materials["logos"], &"us_open", Vector3(0.0, 0.071, 0.0), Vector3.FORWARD, 0.1
	)
	return geometry


## A towel hanging over a chair's back: its origin is where it lies on the back's top edge.
func _hanging_towel() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var hang: float = 0.66
	for side: float in [-1.0, 1.0]:
		# Each half hangs down from the edge, its bottom a little away from the chair's back
		var tilt := Basis(Vector3.RIGHT, -side * 0.12)
		geometry.box(
			_materials["towel"],
			Transform3D(tilt, tilt * Vector3(0.0, -hang * 0.5, 0.0) + Vector3.BACK * side * 0.02),
			Vector3(0.4, hang, 0.02)
		)
	return geometry


## An evian bottle: a pale blue body with a pink label and cap.
func _water_bottle() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var bottle: Material = _materials["bottle"]
	var label: Material = _materials["bottle_label"]
	_upright(geometry, bottle, bottle, BOTTLE_SIZE.x, 0.0, BOTTLE_SIZE.y)
	_upright(geometry, label, label, BOTTLE_SIZE.x * 1.04, 0.07, 0.15)
	_upright(geometry, bottle, bottle, BOTTLE_SIZE.x * 0.45, BOTTLE_SIZE.y, BOTTLE_SIZE.y + 0.025)
	_upright(
		geometry, label, label, BOTTLE_SIZE.x * 0.52, BOTTLE_SIZE.y + 0.025, BOTTLE_SIZE.y + 0.045
	)
	return geometry


## An upright round prism of `radius` from height `bottom` to `top`.
func _upright(
	geometry: FlatGeometry,
	material: Material,
	cap_material: Material,
	radius: float,
	bottom: float,
	top: float
) -> void:
	var up := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	geometry.extrusion(
		material,
		cap_material,
		Transform3D(up, Vector3(0.0, (bottom + top) * 0.5, 0.0)),
		FlatGeometry.circle_outline(Vector2.ONE * radius, ROUND_SIDES),
		top - bottom
	)


## A racket bag lying along x: a rounded body with end panels and a strap along the top in the
## accent color, and two handles.
func _tennis_bag() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var body: Material = _materials["bag_body"]
	var accent: Material = _materials["bag_accent"]
	var half := Vector2(BAG_SIZE.y, BAG_SIZE.z) * 0.5
	# Cross-section: a box with cut corners, the flat bottom on the floor
	var outline := PackedVector2Array(
		[
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y * 0.45),
			Vector2(half.x * 0.6, half.y),
			Vector2(-half.x * 0.6, half.y),
			Vector2(-half.x, half.y * 0.45),
		]
	)
	var along_x := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)
	geometry.extrusion(
		body, accent, Transform3D(along_x, Vector3(0.0, half.y, 0.0)), outline, BAG_SIZE.x
	)
	geometry.box(
		accent,
		Transform3D(Basis(), Vector3(0.0, BAG_SIZE.z + 0.004, 0.0)),
		Vector3(BAG_SIZE.x * 0.98, 0.008, half.x * 0.7)
	)
	for x: float in [-0.12, 0.12]:
		geometry.beam(
			_materials["black"],
			Vector3(x, BAG_SIZE.z, -0.06),
			Vector3(x, BAG_SIZE.z + 0.06, 0.0),
			0.02
		)
		geometry.beam(
			_materials["black"],
			Vector3(x, BAG_SIZE.z + 0.06, 0.0),
			Vector3(x, BAG_SIZE.z, 0.06),
			0.02
		)
	return geometry


## A photographer's place: a stool, and a camera with a long white lens held at chest height
## towards the court on a monopod.
func _photographer() -> FlatGeometry:
	var geometry := _operator_stool()
	var body := Vector3(0.0, 1.0, 0.42)
	geometry.box(_materials["black"], Transform3D(Basis(), body), Vector3(0.14, 0.13, 0.12))
	geometry.beam(_materials["white"], body + Vector3.BACK * 0.06, body + Vector3.BACK * 0.5, 0.11)
	geometry.beam(_materials["black"], body + Vector3.BACK * 0.5, body + Vector3.BACK * 0.56, 0.12)
	geometry.beam(
		_materials["black"], body + Vector3.BACK * 0.25, Vector3(body.x, 0.0, body.z + 0.25), 0.025
	)
	return geometry


## The stool a photographer or TV camera operator sits on.
func _operator_stool() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	geometry.box(
		_materials["dark_steel"],
		Transform3D(Basis(), Vector3(0.0, 0.21, -0.05)),
		Vector3(0.34, 0.42, 0.34)
	)
	return geometry
