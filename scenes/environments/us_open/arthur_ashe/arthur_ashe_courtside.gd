class_name ArthurAsheCourtside
extends RefCounted
## Builds the court level of Arthur Ashe Stadium (see ArthurAsheBuilder), as in the 2025 final:
## - the field, a rectangle, and the plaza outside the stadium;
## - behind each baseline a tall blue wall with the sponsors' logos, reaching from stand to stand
##   (the serve speed, match time and serve clock displays on it are scenes of the stadium);
## - along the long sides straight, low blue ad boards, ending short of the walls so people can
##   walk through at the corners. Behind the left board (as seen from the main TV camera) the
##   courtside seats begin right away; behind the right one a pit at court level runs in front
##   of the first row, where the photographers sit along the whole court and the TV cameras
##   stand next to the net;
## The positions were measured from the US Open 2025 final's broadcast.
## - the players' benches beside the umpire chair: a white chair and a navy box on a mat.

## Low ad boards along the sides: height and depth (m)
const BOARD: Vector2 = Vector2(0.85, 0.15)
## Walls behind the baselines: height and depth (m)
const BACK_WALL: Vector2 = Vector2(2.5, 0.3)
## Offset of the pit's back from the boards, where the stands begin
const PIT_DEPTH: float = 2.2
## Half width of the walls behind the baselines, from the field's middle (m)
const WALL_HALF_WIDTH: float = 17.5
## Courtside seats behind the left board, in the pit: offset of each row's front and its floor
## height, and the depth of a row
const COURTSIDE_ROWS: Array[Vector2] = [Vector2(0.3, 0.05), Vector2(1.25, 0.32)]
const COURTSIDE_ROW_DEPTH: float = 0.95
## Gap between the side boards' ends and the walls behind the baselines, a walkway (m)
const CORNER_GAP: float = 1.0
## Logos on the walls behind the baselines, from the left to the right as seen from the court:
## logo, x (m, from the court's middle), height of its middle (m) and its height (m)
const FAR_WALL_LOGOS: Array[Array] = [
	[&"american_express", -15.3, 2.06, 0.56],
	[&"emirates", -10.3, 2.09, 0.42],
	[&"usopen_org", -7.1, 2.33, 0.12],
	[&"ibm", -7.05, 1.07, 0.26],
	[&"jp_morgan", -3.65, 1.7, 0.44],
	[&"us_open_finals", 0.0, 1.54, 0.95],
	[&"jp_morgan", 3.65, 1.7, 0.44],
	[&"usopen_org", 7.1, 2.33, 0.12],
	[&"emirates", 10.3, 2.07, 0.42],
	[&"american_express", 14.4, 2.03, 0.56],
]
const NEAR_WALL_LOGOS: Array[Array] = [
	[&"american_express", -15.3, 2.06, 0.56],
	[&"emirates", -10.3, 2.09, 0.42],
	[&"usopen_org", -7.1, 2.33, 0.12],
	[&"ibm", -7.05, 1.07, 0.26],
	[&"chase", -3.65, 1.7, 0.4],
	[&"us_open_finals", 0.0, 1.54, 0.95],
	[&"chase", 3.65, 1.7, 0.4],
	[&"usopen_org", 7.1, 2.33, 0.12],
	[&"emirates", 10.3, 2.07, 0.42],
	[&"american_express", 14.4, 2.03, 0.56],
]
## Dark openings at the foot of the walls behind the baselines (x, width), and small CHASE logos
## between them (x)
const WALL_OPENINGS: Array[Vector2] = [
	Vector2(-4.3, 1.8), Vector2(3.0, 1.1), Vector2(5.5, 1.1), Vector2(8.2, 1.1)
]
const WALL_CHASE: PackedFloat32Array = [-5.7, 0.25, 4.3]
## Logos along the side boards, on the right (+x) and the left (-x) of the main TV camera,
## from the near end to the far end
const RIGHT_BOARD_LOGOS: Array[StringName] = [
	&"usopen_org", &"wilson", &"evian", &"deloitte", &"chubb", &"argenx", &"ihg", &"fage"
]
const LEFT_BOARD_LOGOS: Array[StringName] = [
	&"fage", &"deloitte", &"ihg", &"evian", &"wilson", &"chubb", &"argenx", &"usopen_org"
]
## Photographers in the pit on the right: offset from the board, spacing (m), and the gap
## around the net (half length) where the TV cameras stand
const PHOTOGRAPHERS: Vector3 = Vector3(1.15, 0.72, 2.4)
## Where the operators of the TV cameras next to the net sit in the pit, behind their cameras
## (which the stadium scene places 0.85 m behind the board): offset, and z of each
const OPERATOR_OFFSET: float = 1.6
const TV_CAMERA_Z: PackedFloat32Array = [-1.5, 0.0, 1.5]
## The players' benches: x of the box's front (the spare rackets lean against it), and how far
## from the net they reach (from, to)
const BENCH_FRONT: float = -7.55
const BENCH_SPAN: Vector2 = Vector2(2.4, 4.0)

var _shape: StadiumShape
## Middle (x, z) and half size (m) of the field inside the walls and boards
var _center: Vector2
var _field: Vector2
var _materials: Dictionary[String, Material]
var _logos: Material
## Floor height of the first row of seats, behind the pit
var _first_row_height: float
var _photographers := PackedVector4Array()
var _courtside_seats := PackedVector4Array()


func _init(
	shape: StadiumShape,
	field_center: Vector2,
	field_half_size: Vector2,
	materials: Dictionary[String, Material],
	first_row_height: float
) -> void:
	_shape = shape
	_center = field_center
	_field = field_half_size
	_materials = materials
	_logos = materials["logos"]
	_first_row_height = first_row_height


func build() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	_build_floors(geometry)
	_build_walls(geometry)
	# The pit behind the boards (lower than the field, which covers it inside the walls), and
	# the wall in front of the first row
	_shape.ring_floor(geometry, _materials["pit"], 0.0, PIT_DEPTH, -0.02, true, 0.0)
	_shape.ring_wall(
		geometry, _materials["partition"], PIT_DEPTH, -0.02, _first_row_height, true, 0.02
	)
	_build_logos(geometry)
	_build_courtside_seats(geometry)
	_build_photographers(geometry)
	for end: float in [1.0, -1.0]:
		_build_bench(geometry, end)
	return geometry


## Where the photographers and TV camera operators sit (see StadiumSeating), once built.
func photographers() -> PackedVector4Array:
	return _photographers


## The courtside seats behind the left board (see StadiumSeating), once built.
func courtside_seats() -> PackedVector4Array:
	return _courtside_seats


func _build_floors(geometry: FlatGeometry) -> void:
	var left: float = _center.x - _field.x
	var right: float = _center.x + _field.x
	geometry.quad(
		_materials["field"],
		Vector3(left, -0.01, -_field.y),
		Vector3(right, -0.01, -_field.y),
		Vector3(right, -0.01, _field.y),
		Vector3(left, -0.01, _field.y),
		Vector3.UP
	)
	var plaza: float = 350.0
	geometry.quad(
		_materials["plaza"],
		Vector3(-plaza, -0.03, -plaza),
		Vector3(plaza, -0.03, -plaza),
		Vector3(plaza, -0.03, plaza),
		Vector3(-plaza, -0.03, plaza),
		Vector3.UP
	)


## The walls behind the baselines from stand to stand, and the boards along the sides, ending
## short of them.
func _build_walls(geometry: FlatGeometry) -> void:
	var wall: Material = _materials["wall"]
	for end: float in [1.0, -1.0]:
		var z: float = end * _field.y
		var back: float = end * (_field.y + BACK_WALL.y)
		_box(
			geometry,
			wall,
			Vector3(_center.x - WALL_HALF_WIDTH, 0.0, z),
			Vector3(_center.x + WALL_HALF_WIDTH, BACK_WALL.x, back)
		)
	var board_end: float = _field.y - CORNER_GAP
	for side: float in [1.0, -1.0]:
		var x: float = _center.x + side * _field.x
		_box(
			geometry,
			wall,
			Vector3(x, 0.0, -board_end),
			Vector3(x + side * BOARD.y, BOARD.x, board_end)
		)


## A box between two opposite corners.
func _box(geometry: FlatGeometry, material: Material, from: Vector3, to: Vector3) -> void:
	geometry.box(material, Transform3D(Basis(), (from + to) * 0.5), (to - from).abs())


func _build_logos(geometry: FlatGeometry) -> void:
	for end: float in [1.0, -1.0]:
		# Seen from the court, +x is on the left at the near end (+z)
		var near: bool = end > 0.0
		var facing := Vector3(0.0, 0.0, -end)
		var z: float = end * (_field.y - 0.012)
		for logo: Array in NEAR_WALL_LOGOS if near else FAR_WALL_LOGOS:
			var x: float = -logo[1] if near else logo[1]
			UsOpenLogos.add(geometry, _logos, logo[0], Vector3(x, logo[2], z), facing, logo[3])
		for opening in WALL_OPENINGS:
			var x: float = -opening.x if near else opening.x
			geometry.box(
				_materials["black"],
				Transform3D(Basis(), Vector3(x, 0.42, z)),
				Vector3(opening.y, 0.34, 0.01)
			)
		for x in WALL_CHASE:
			UsOpenLogos.add(
				geometry, _logos, &"chase", Vector3(-x if near else x, 0.2, z), facing, 0.12
			)
	for side: float in [1.0, -1.0]:
		var logos: Array[StringName] = RIGHT_BOARD_LOGOS if side > 0.0 else LEFT_BOARD_LOGOS
		var x: float = _center.x + side * (_field.x - 0.012)
		var board_end: float = _field.y - CORNER_GAP
		for i in logos.size():
			var z: float = lerpf(board_end, -board_end, (i + 0.5) / logos.size())
			UsOpenLogos.add(
				geometry,
				_logos,
				logos[i],
				Vector3(x, BOARD.x * 0.5, z),
				Vector3(-side, 0.0, 0.0),
				0.4
			)


## The courtside seats behind the left board: rows of seats on steps in the pit, from wall to
## wall, so the crowd sits right behind the board.
func _build_courtside_seats(geometry: FlatGeometry) -> void:
	var back: float = _center.x - _field.x - BOARD.y
	var reach: float = _field.y - CORNER_GAP
	var angle: float = atan2(1.0, 0.0)
	for row in COURTSIDE_ROWS:
		var front: float = back - row.x
		var depth: float = COURTSIDE_ROW_DEPTH if row != COURTSIDE_ROWS[-1] else PIT_DEPTH - row.x
		_box(
			geometry,
			_materials["concrete"],
			Vector3(front - depth, -0.02, -reach),
			Vector3(front, row.y, reach)
		)
		var count: int = floori(reach * 2.0 / 0.52)
		for i in count:
			var z: float = lerpf(-reach, reach, (i + 0.5) / count)
			_courtside_seats.append(Vector4(front - depth * 0.58, row.y, z, angle))


## The photographers' row in the pit on the right, along the whole court except around the net
## where the TV cameras stand: stools, and cameras with long white lenses pointed at the court.
## The TV camera operators sit behind their cameras.
func _build_photographers(geometry: FlatGeometry) -> void:
	var x: float = _center.x + _field.x + PHOTOGRAPHERS.x
	var facing := Vector3(-1.0, 0.0, 0.0)
	var angle: float = atan2(facing.x, facing.z)
	var reach: float = _field.y - CORNER_GAP - 0.4
	var count: int = floori((reach - PHOTOGRAPHERS.z) / PHOTOGRAPHERS.y) + 1
	for side: float in [1.0, -1.0]:
		for i in count:
			var spot := Vector3(x, 0.0, side * (PHOTOGRAPHERS.z + i * PHOTOGRAPHERS.y))
			_photographers.append(Vector4(spot.x, 0.0, spot.z, angle))
			_stool(geometry, spot)
			# Camera body and lens, held at chest height towards the court
			var body := spot + facing * 0.42 + Vector3.UP * 1.0
			geometry.box(_materials["black"], Transform3D(Basis(), body), Vector3(0.14, 0.13, 0.12))
			geometry.beam(_materials["white"], body + facing * 0.06, body + facing * 0.5, 0.11)
			geometry.beam(_materials["black"], body + facing * 0.5, body + facing * 0.56, 0.12)
			# Monopod down to the floor
			geometry.beam(
				_materials["black"],
				body + facing * 0.25,
				Vector3(body.x - 0.25, 0.0, body.z),
				0.025
			)
	for camera_z in TV_CAMERA_Z:
		var spot := Vector3(_center.x + _field.x + OPERATOR_OFFSET, 0.0, camera_z)
		_photographers.append(Vector4(spot.x, 0.0, spot.z, angle))
		_stool(geometry, spot)


func _stool(geometry: FlatGeometry, at: Vector3) -> void:
	geometry.box(
		_materials["dark_steel"],
		Transform3D(Basis(), at + Vector3(0.05, 0.21, 0.0)),
		Vector3(0.34, 0.42, 0.34)
	)


## A player's bench on the umpire's side (-x), on the near (`end` 1) or far side of the net:
## a mat with the Polo pony at both ends, a navy Polo box the spare rackets lean against, and a
## white chair next to the umpire chair.
func _build_bench(geometry: FlatGeometry, end: float) -> void:
	var navy: Material = _materials["fascia"]
	var mat_center := Vector3(BENCH_FRONT - 0.35, 0.004, end * 2.35)
	geometry.box(
		navy, Transform3D(Basis(), mat_center), Vector3(1.4, 0.012, 3.3), Color(0.6, 0.6, 0.65)
	)
	for along: float in [-1.35, 1.35]:
		UsOpenLogos.add_flat(
			geometry,
			_logos,
			&"polo_pony",
			mat_center + Vector3(0.0, 0.008, along * end),
			Vector3(0.0, 0.0, -end),
			0.4
		)
	# Box with towels on top, its ends and its front showing POLO
	var box_center := Vector3(BENCH_FRONT - 0.27, 0.23, end * (BENCH_SPAN.x + BENCH_SPAN.y) * 0.5)
	var box_size := Vector3(0.54, 0.46, BENCH_SPAN.y - BENCH_SPAN.x)
	geometry.box(navy, Transform3D(Basis(), box_center), box_size)
	for face: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD]:
		var offset: Vector3 = face * (box_size * 0.5 + Vector3.ONE * 0.003)
		UsOpenLogos.add(
			geometry, _logos, &"polo", box_center + offset + Vector3.UP * 0.05, face, 0.12
		)
	geometry.box(
		_materials["white"],
		Transform3D(Basis(), box_center + Vector3(0.0, 0.26, end * -0.35)),
		Vector3(0.45, 0.06, 0.55)
	)
	geometry.box(
		_materials["towel"],
		Transform3D(Basis(), box_center + Vector3(0.02, 0.26, end * 0.4)),
		Vector3(0.42, 0.07, 0.5)
	)
	# White chair facing the court, next to the umpire chair
	var chair := Vector3(BENCH_FRONT - 0.3, 0.0, end * 1.3)
	var white: Material = _materials["white"]
	geometry.box(
		white, Transform3D(Basis(), chair + Vector3(0.0, 0.45, 0.0)), Vector3(0.5, 0.06, 0.5)
	)
	geometry.box(
		white,
		Transform3D(Basis(Vector3.BACK, -0.1), chair + Vector3(-0.27, 0.78, 0.0)),
		Vector3(0.05, 0.62, 0.5)
	)
	for side: float in [-0.23, 0.23]:
		geometry.box(
			white, Transform3D(Basis(), chair + Vector3(0.0, 0.22, side)), Vector3(0.5, 0.44, 0.04)
		)
	# A towel hanging over the chair's back
	geometry.box(
		_materials["towel"],
		Transform3D(Basis(Vector3.BACK, -0.1), chair + Vector3(-0.31, 0.72, 0.0)),
		Vector3(0.04, 0.7, 0.4)
	)
