class_name ArthurAsheRoof
extends RefCounted
## Builds the roof of Arthur Ashe Stadium (see ArthurAsheBuilder): a fixed ring around the open
## middle, carried by an inner ring truss and trusses running out to its edge, and over the long
## sides the two retractable roof panels, parked open on four huge trusses on eight columns.

## Inner ring truss: offset of its two sides, bottom and top (m)
const RING_TRUSS: Vector4 = Vector4(26.0, 29.0, 38.5, 42.6)
## The fixed roof runs out to ROOF_EDGE, sloping down to ROOF_EDGE_HEIGHT
const ROOF_EDGE: float = 48.0
const ROOF_EDGE_HEIGHT: float = 41.0
## The four trusses the roof panels ride on: x of each, and bottom, top and half length along z
const SUPER_TRUSS_X: PackedFloat32Array = [-58.0, -37.0, 37.0, 58.0]
const SUPER_TRUSS: Vector3 = Vector3(43.5, 50.0, 66.0)

var _shape: StadiumShape
var _materials: Dictionary[String, Material]


func _init(shape: StadiumShape, materials: Dictionary[String, Material]) -> void:
	_shape = shape
	_materials = materials


## Frames of the video boards, with the cables they hang from.
func build_video_board_frames() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	for board in _video_boards():
		var size: Vector2 = board.size
		var basis: Basis = board.place.basis
		var center: Vector3 = board.place.origin
		geometry.box(
			_materials["black"],
			Transform3D(basis, center - basis.z * 0.35),
			Vector3(size.x + 0.5, size.y + 0.5, 0.6)
		)
		for x: float in [-size.x * 0.35, size.x * 0.35]:
			var hook: Vector3 = center + basis.x * x + Vector3.UP * (size.y * 0.5 + 0.25)
			geometry.beam(_materials["black"], hook, Vector3(hook.x, RING_TRUSS.z, hook.z), 0.06)
	return geometry


## Screens of the video boards, showing the TV picture.
func video_screens() -> Array[MeshInstance3D]:
	var mesh := QuadMesh.new()
	mesh.material = _materials["video_board"]
	var screens: Array[MeshInstance3D] = []
	for board in _video_boards():
		var size: Vector2 = board.size
		var place: Transform3D = board.place
		var screen := MeshInstance3D.new()
		screen.name = "Screen%d" % screens.size()
		screen.mesh = mesh
		screen.transform = Transform3D(
			place.basis.scaled_local(Vector3(size.x, size.y, 1.0)),
			place.origin + place.basis.z * 0.01
		)
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		screen.set_instance_shader_parameter("aspect", size.x / size.y)
		screens.append(screen)
	return screens


## The Stars and Stripes hanging from the ring truss over the far end, next to its video board.
func flag() -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3.4, 6.4)
	mesh.subdivide_width = 6
	mesh.subdivide_depth = 16
	mesh.material = _materials["flag"]
	var flag_mesh := MeshInstance3D.new()
	flag_mesh.name = "Flag"
	flag_mesh.mesh = mesh
	var at: Vector2 = _shape.on_edge(_far_end(), 0.5, RING_TRUSS.x - 0.6)
	flag_mesh.transform = Transform3D(Basis(), Vector3(at.x + 9.5, RING_TRUSS.z - 3.4, at.y))
	return flag_mesh


## The fixed roof ring with its trusses, lights and speakers, and the trusses and columns the roof
## panels ride on.
func build() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var steel: Material = _materials["steel"]
	var inner: float = RING_TRUSS.x
	var outer: float = RING_TRUSS.y
	var bottom: float = RING_TRUSS.z
	var top: float = RING_TRUSS.w
	# Fixed roof ring
	_shape.ring_slope(
		geometry,
		_materials["membrane"],
		Vector2(inner, top + 0.2),
		Vector2(ROOF_EDGE, ROOF_EDGE_HEIGHT),
		true,
		0.02
	)
	_shape.ring_wall(
		geometry,
		_materials["steel"],
		ROOF_EDGE,
		ROOF_EDGE_HEIGHT - 1.2,
		ROOF_EDGE_HEIGHT,
		false,
		0.0
	)
	_shape.ring_wall(geometry, _materials["steel"], inner, bottom + 2.6, top + 0.2, true, 0.0)
	# Inner ring truss: two Warren trusses, tied together
	for edge in _shape.edge_count():
		var panels: int = maxi(1, ceili(_shape.edge_length(edge, inner) / 3.5))
		for i in panels:
			var t0: float = float(i) / panels
			var t1: float = float(i + 1) / panels
			for d: float in [inner, outer]:
				var a: Vector2 = _shape.on_edge(edge, t0, d)
				var b: Vector2 = _shape.on_edge(edge, t1, d)
				var low_a := Vector3(a.x, bottom, a.y)
				var low_b := Vector3(b.x, bottom, b.y)
				var high_a := Vector3(a.x, top, a.y)
				var high_b := Vector3(b.x, top, b.y)
				geometry.beam(steel, low_a, low_b, 0.45)
				geometry.beam(steel, high_a, high_b, 0.45)
				geometry.beam(steel, low_a, high_a, 0.3)
				geometry.beam(
					steel, low_a if i % 2 == 0 else high_a, high_b if i % 2 == 0 else low_b, 0.25
				)
			var near: Vector2 = _shape.on_edge(edge, t0, inner)
			var far: Vector2 = _shape.on_edge(edge, t0, outer)
			geometry.beam(
				steel, Vector3(near.x, bottom, near.y), Vector3(far.x, bottom, far.y), 0.25
			)
			geometry.beam(steel, Vector3(near.x, bottom, near.y), Vector3(far.x, top, far.y), 0.2)
			# Lights along the truss's bottom, facing the court
			var lamp: Vector2 = _shape.on_edge(edge, (t0 + t1) * 0.5, inner - 0.3)
			var facing: Vector3 = -_shape.outward(edge)
			geometry.box(
				_materials["lamp"],
				Transform3D(
					Basis(Vector3.UP.cross(facing), Vector3.UP, facing).rotated(
						Vector3.UP.cross(facing), 0.5
					),
					Vector3(lamp.x, bottom - 0.2, lamp.y)
				),
				Vector3(0.7, 0.45, 0.25)
			)
	# Radial trusses under the fixed roof and rings of purlins
	for vertex in _shape.edge_count():
		_radial_truss(geometry, vertex, 0.0)
		if _shape.is_side(vertex):
			for t: float in [0.25, 0.5, 0.75]:
				_radial_truss(geometry, vertex, t)
	for d: float in [32.0, 36.0, 40.0, 44.0, 47.5]:
		for edge in _shape.edge_count():
			var height: float = _roof_height(d) - 0.3
			geometry.beam(
				steel, _shape.point(edge, d, height), _shape.point(edge + 1, d, height), 0.25
			)
	# Speakers hanging between the lights
	for vertex in _shape.edge_count():
		if _shape.facet(vertex) % 2 == 1:
			var at: Vector2 = _shape.at(vertex, inner + 1.5)
			geometry.box(
				_materials["black"],
				Transform3D(Basis(), Vector3(at.x, bottom - 2.2, at.y)),
				Vector3(1.1, 2.6, 1.1)
			)
			geometry.beam(
				_materials["black"],
				Vector3(at.x, bottom - 0.9, at.y),
				Vector3(at.x, bottom, at.y),
				0.05
			)
	_build_super_trusses(geometry)
	return geometry


func _roof_height(d: float) -> float:
	return remap(d, RING_TRUSS.x, ROOF_EDGE, RING_TRUSS.w + 0.2, ROOF_EDGE_HEIGHT)


## A truss under the fixed roof from the ring truss out to the roof's edge, at `t` along the edge
## starting at `vertex`.
func _radial_truss(geometry: FlatGeometry, vertex: int, t: float) -> void:
	var steel: Material = _materials["steel"]
	var panels: int = 7
	for i in panels:
		var d0: float = lerpf(RING_TRUSS.y, ROOF_EDGE, float(i) / panels)
		var d1: float = lerpf(RING_TRUSS.y, ROOF_EDGE, float(i + 1) / panels)
		var a: Vector2 = _shape.on_edge(vertex, t, d0)
		var b: Vector2 = _shape.on_edge(vertex, t, d1)
		var high_a := Vector3(a.x, _roof_height(d0) - 0.3, a.y)
		var high_b := Vector3(b.x, _roof_height(d1) - 0.3, b.y)
		var low_a := Vector3(
			a.x, lerpf(RING_TRUSS.z, ROOF_EDGE_HEIGHT - 1.5, float(i) / panels), a.y
		)
		var low_b := Vector3(
			b.x, lerpf(RING_TRUSS.z, ROOF_EDGE_HEIGHT - 1.5, float(i + 1) / panels), b.y
		)
		geometry.beam(steel, high_a, high_b, 0.35)
		geometry.beam(steel, low_a, low_b, 0.35)
		geometry.beam(steel, low_a, high_a, 0.22)
		geometry.beam(steel, low_a, high_b, 0.18)


## The four trusses along the long sides the roof panels ride on, on their eight columns.
func _build_super_trusses(geometry: FlatGeometry) -> void:
	var steel: Material = _materials["steel"]
	var bottom: float = SUPER_TRUSS.x
	var top: float = SUPER_TRUSS.y
	var half_length: float = SUPER_TRUSS.z
	var panels: int = 33
	for x in SUPER_TRUSS_X:
		for side: float in [-1.6, 1.6]:
			for i in panels:
				var z0: float = lerpf(-half_length, half_length, float(i) / panels)
				var z1: float = lerpf(-half_length, half_length, float(i + 1) / panels)
				geometry.beam(
					steel, Vector3(x + side, bottom, z0), Vector3(x + side, bottom, z1), 0.7
				)
				geometry.beam(steel, Vector3(x + side, top, z0), Vector3(x + side, top, z1), 0.7)
				geometry.beam(
					steel, Vector3(x + side, bottom, z0), Vector3(x + side, top, z0), 0.45
				)
				var rising: bool = i % 2 == 0
				geometry.beam(
					steel,
					Vector3(x + side, bottom if rising else top, z0),
					Vector3(x + side, top if rising else bottom, z1),
					0.4
				)
		for i in panels + 1:
			var z: float = lerpf(-half_length, half_length, float(i) / panels)
			geometry.beam(steel, Vector3(x - 1.6, top, z), Vector3(x + 1.6, top, z), 0.35)
			geometry.beam(steel, Vector3(x - 1.6, bottom, z), Vector3(x + 1.6, bottom, z), 0.35)
		# Columns at both ends, braced to the ground
		for end: float in [-1.0, 1.0]:
			var z: float = end * half_length
			geometry.box(
				steel, Transform3D(Basis(), Vector3(x, top * 0.5, z)), Vector3(3.6, top, 2.4)
			)
			for lean: float in [-1.0, 1.0]:
				geometry.beam(
					steel, Vector3(x + lean * 9.0, 0.0, z), Vector3(x, bottom - 4.0, z), 1.1
				)
			geometry.box(
				_materials["concrete"],
				Transform3D(Basis(), Vector3(x, 0.5, z)),
				Vector3(6.0, 1.0, 5.0)
			)


## The two retractable roof panels, parked open over the long sides: vaults with ribs.
func build_panels() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var across: int = 12
	var along: int = 20
	var half_length: float = 60.0
	for side: float in [-1.0, 1.0]:
		var inner: float = side * (absf(SUPER_TRUSS_X[2]) - 1.8)
		var outer: float = side * (absf(SUPER_TRUSS_X[3]) + 1.8)
		var vault := func(t: float) -> float: return SUPER_TRUSS.y + 0.6 + sin(t * PI) * 4.5
		for j in along:
			var z0: float = lerpf(-half_length, half_length, float(j) / along)
			var z1: float = lerpf(-half_length, half_length, float(j + 1) / along)
			for i in across:
				var t0: float = float(i) / across
				var t1: float = float(i + 1) / across
				var x0: float = lerpf(inner, outer, t0)
				var x1: float = lerpf(inner, outer, t1)
				geometry.quad(
					_materials["membrane"],
					Vector3(x0, vault.call(t0), z0),
					Vector3(x1, vault.call(t1), z0),
					Vector3(x1, vault.call(t1), z1),
					Vector3(x0, vault.call(t0), z1),
					Vector3.UP,
					_shape.shade(0.015)
				)
				# Ribs across the vault
				geometry.beam(
					_materials["steel"],
					Vector3(x0, vault.call(t0) - 0.35, z0),
					Vector3(x1, vault.call(t1) - 0.35, z0),
					0.5
				)
				if j == along - 1:
					geometry.beam(
						_materials["steel"],
						Vector3(x0, vault.call(t0) - 0.35, z1),
						Vector3(x1, vault.call(t1) - 0.35, z1),
						0.5
					)
			for edge_x: float in [inner, outer]:
				geometry.beam(
					_materials["steel"],
					Vector3(edge_x, SUPER_TRUSS.y + 0.3, z0),
					Vector3(edge_x, SUPER_TRUSS.y + 0.3, z1),
					0.8
				)
		# Gable ends closing the vault
		for z: float in [-half_length, half_length]:
			for i in across:
				var t0: float = float(i) / across
				var t1: float = float(i + 1) / across
				var x0: float = lerpf(inner, outer, t0)
				var x1: float = lerpf(inner, outer, t1)
				geometry.quad(
					_materials["membrane"],
					Vector3(x0, SUPER_TRUSS.y + 0.6, z),
					Vector3(x1, SUPER_TRUSS.y + 0.6, z),
					Vector3(x1, vault.call(t1), z),
					Vector3(x0, vault.call(t0), z),
					Vector3(0.0, 0.0, signf(z)),
					_shape.shade(0.015)
				)
	return geometry


## Where the video boards hang from the ring truss, facing the court (+Z), and their sizes: one
## in every corner and one at each end.
func _video_boards() -> Array[Dictionary]:
	var boards: Array[Dictionary] = []
	for corner in 4:
		@warning_ignore("integer_division")
		var at: Vector2 = _shape.at(
			corner * (_shape.corner_facets + 1) + _shape.corner_facets / 2, RING_TRUSS.x - 1.5
		)
		boards.append(_video_board(at, -Vector3(at.x, 0.0, at.y).normalized(), Vector2(10.0, 5.6)))
	for edge in _shape.edge_count():
		if _shape.is_side(edge) and not _shape.is_long_side(edge):
			var at: Vector2 = _shape.on_edge(edge, 0.5, RING_TRUSS.x - 1.5)
			boards.append(_video_board(at, -_shape.outward(edge), Vector2(12.0, 6.75)))
	return boards


func _video_board(at: Vector2, facing: Vector3, size: Vector2) -> Dictionary:
	var center := Vector3(at.x, RING_TRUSS.z - 1.4 - size.y * 0.5, at.y)
	var basis := Basis(Vector3.UP.cross(facing), Vector3.UP, facing)
	return {place = Transform3D(basis, center), size = size}


## The end behind the baseline away from the main TV camera (at -Z): the side after the third
## corner
func _far_end() -> int:
	return 3 * (_shape.corner_facets + 1) - 1
