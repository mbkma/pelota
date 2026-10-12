class_name ArthurAsheCourtside
extends RefCounted
## Builds the court level of Arthur Ashe Stadium (see ArthurAsheBuilder), as in the 2025 final:
## - the field, a rectangle, and the plaza outside the stadium;
## - behind each baseline a tall blue wall with the sponsors' logos, reaching from stand to stand
##   (the serve speed, match time and serve clock displays on it are scenes of the stadium);
## - along the long sides straight, low blue ad boards, ending short of the walls so people can
##   walk through at the corners. Behind the left board (as seen from the main TV camera) the
##   courtside seats begin right away; behind the right one a pit at court level runs in front
##   of the first row, where the photographers sit along the court and the TV cameras stand
##   next to the net.
## The positions were measured from the US Open 2025 final's broadcast. The props at court level
## (the players' benches, the photographers' and camera operators' places, towels, bottles and
## bags) are scenes placed in the stadium scene (see CourtsidePropsBuilder).

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

var _shape: StadiumShape
## Middle (x, z) and half size (m) of the field inside the walls and boards
var _center: Vector2
var _field: Vector2
var _materials: Dictionary[String, Material]
var _logos: Material
## Floor height of the first row of seats, behind the pit
var _first_row_height: float
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
	return geometry


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
