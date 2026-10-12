## Builds the Arthur Ashe Stadium, the center court of the US Open, from code. Run it after
## changing it:
##
##     godot --headless --path . \
##         -s res://scenes/environments/us_open/arthur_ashe/arthur_ashe_builder.gd
##
## It writes the meshes into MESH_DIR, the seats into SEATING_PATH (which the crowd sits on too)
## and the stadium into SCENE_PATH.
##
## The stands run around the field along a StadiumShape: everything in the bowl is placed by its
## offset from it (how far out from the field wall, called d) and its height, so rows, aisles,
## fascias and the roof follow the bowl's shape. From the field outwards, as in the real stadium:
## - the court level (see ArthurAsheCourtside);
## - the lower bowl: the first tier, a cross aisle and the second tier behind a terracotta wall;
## - two rings of suites with glass fronts and balconies, under blue fascias with the sponsors'
##   logos (see UsOpenLogos) and a glowing LED ribbon;
## - the steep upper bowl up to the rim, and the brick facade outside;
## - the roof (see ArthurAsheRoof);
## - video boards, lights, speakers and the flag hanging from the roof's inner truss.
class_name ArthurAsheBuilder
extends SceneTree

const SCENE_PATH: String = "res://scenes/environments/us_open/arthur_ashe/arthur_ashe.tscn"
const MESH_DIR: String = "res://scenes/environments/us_open/arthur_ashe/meshes/"
const SEATING_PATH: String = "res://scenes/environments/us_open/arthur_ashe/seating.res"

## Half size (m) of the field inside the field wall (x, z), and its corners
const FIELD_HALF_SIZE: Vector2 = Vector2(11.7, 20.47)
## The field is not centered on the court: there is more room on the umpire's side (x, z)
const FIELD_CENTER: Vector2 = Vector2(-0.75, 0.0)
const CORNER_RADIUS: float = 0.5
const CORNER_FACETS: int = 4

## Seat width (m), gap kept to aisles and kinks, and aisle width
const SEAT_WIDTH: float = 0.52
const SEAT_GAP: float = 0.1
const AISLE_WIDTH: float = 1.2
## Seats of a row between two aisles, roughly (m)
const SECTION_LENGTH: float = 9.0
## Suites along the suite rings, roughly (m)
const SUITE_LENGTH: float = 4.6
## Where the seat stands on its row, from the row's front (share of the row's depth)
const SEAT_POSITION: float = 0.58

## Cross aisle between the lower bowl's tiers: from the first tier's back to this offset, at
## this height; the wall in front of the second tier rises to SECOND_TIER_WALL_TOP.
const CROSS_AISLE_BACK: float = 15.5
const CROSS_AISLE_HEIGHT: float = 5.65
const SECOND_TIER_WALL_TOP: float = 7.35
## Suites: front of their glass, and the fascias (offset, bottom, top)
const SUITE_GLASS: float = 23.4
const SUITE_FASCIA: Vector3 = Vector3(21.55, 13.6, 14.85)
const UPPER_FASCIA: Vector3 = Vector3(21.35, 17.4, 19.3)
const LOWER_SUITE_FRONT: Vector3 = Vector3(21.7, 9.6, 10.95)
## Height of the glowing LED ribbon along the top of the fascia between the suite rings
const RIBBON_HEIGHT: float = 0.35
## Sponsors' logos on the fascias, and roughly how far apart (m)
const LOWER_SUITE_LOGOS: Array[StringName] = [
	&"chase", &"ticketmaster", &"jp_morgan", &"us_open", &"ibm", &"emirates"
]
const SUITE_LOGOS: Array[StringName] = [
	&"ibm", &"argenx", &"espn", &"polo_ralph_lauren", &"fage", &"us_open"
]
const UPPER_LOGOS: Array[StringName] = [
	&"emirates", &"cadillac", &"ibm", &"american_express", &"us_open", &"jp_morgan"
]
const FASCIA_LOGO_SPACING: float = 9.0
## The rim: walkway behind the upper bowl, its back wall and the facade
const RIM_WALKWAY: Vector2 = Vector2(45.3, 32.85)
const RIM_WALL_TOP: float = 35.6
const FACADE: float = 45.6

## TV camera platforms in the stands behind both baselines, where the match's TV cameras and the
## broadcast cameras stand (see the stadium scene; the main camera's place was measured from the
## US Open 2025 final):
## half width, and the lower and upper deck (front offset, back offset, floor height)
const PLATFORM_HALF_WIDTH: float = 2.3
const LOWER_PLATFORM: Vector3 = Vector3(6.9, 9.9, 5.35)
const UPPER_PLATFORM: Vector3 = Vector3(9.9, 13.6, 8.2)

var _shape := StadiumShape.new(FIELD_CENTER, FIELD_HALF_SIZE, CORNER_RADIUS, CORNER_FACETS, 1978)
var _materials: Dictionary[String, Material] = ArthurAsheMaterials.make()
var _root: Node3D
var _seat_mesh: ArrayMesh
## Spectators' seats per section name (see StadiumSeating)
var _sections: Dictionary[String, PackedVector4Array] = {}
var _tiers: Array[StadiumTier] = [
	StadiumTier.new(
		"lower", ArthurAsheCourtside.PIT_DEPTH, 0.85, 15, 0.55, 0.3, 0.006, CROSS_AISLE_HEIGHT, true
	),
	StadiumTier.new("second", 15.75, 0.85, 7, 7.05, 0.4, 0.01, 10.0, true),
	StadiumTier.new("suites", 21.9, 0.75, 2, 10.55, 0.35, 0.0, 10.9, false),
	StadiumTier.new("upper_suites", 21.75, 0.825, 2, 14.45, 0.35, 0.0, 14.8, false),
	StadiumTier.new("upper", 21.55, 0.8, 28, 18.95, 0.45, 0.004, RIM_WALKWAY.y, true),
]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	_root = Node3D.new()
	_root.name = "ArthurAshe"
	_seat_mesh = _make_seat_mesh()

	var courtside := ArthurAsheCourtside.new(
		_shape, FIELD_CENTER, FIELD_HALF_SIZE, _materials, _tiers[0].height
	)
	_add_mesh(_root, "Courtside", courtside.build())
	_sections["courtside_left"] = courtside.courtside_seats()
	_add_mesh(_root, "Bowl", _build_bowl())
	_add_mesh(_root, "Suites", _build_suites())
	_add_mesh(_root, "Facade", _build_facade())
	var roof := ArthurAsheRoof.new(_shape, _materials)
	_add_mesh(_root, "Roof", roof.build())
	_add_mesh(_root, "RoofPanels", roof.build_panels())
	_add_seats()
	var boards := Node3D.new()
	boards.name = "VideoBoards"
	_add(_root, boards)
	for screen in roof.video_screens():
		_add(boards, screen)
	_add_mesh(boards, "VideoBoardFrames", roof.build_video_board_frames())
	_add(_root, roof.flag())
	_add_mesh(_root, "Logos", _build_logos())

	var scene := PackedScene.new()
	scene.pack(_root)
	# Keep the scene's UID: the stadium scene refers to it by it.
	var uid: int = ResourceLoader.get_resource_uid(SCENE_PATH)
	ResourceSaver.save(scene, SCENE_PATH)
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(SCENE_PATH, uid)
	_root.free()
	quit()


# --- Field and bowl ----------------------------------------------------------------------------


func _build_bowl() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var lower: StadiumTier = _tiers[0]
	var second: StadiumTier = _tiers[1]
	var upper: StadiumTier = _tiers[4]
	_build_rows(geometry, lower)
	# Cross aisle and the terracotta wall in front of the second tier
	_shape.ring_wall(
		geometry,
		_materials["concrete"],
		lower.back(),
		lower.row_height(lower.rows - 1),
		CROSS_AISLE_HEIGHT,
		true
	)
	_shape.ring_floor(
		geometry, _materials["concrete"], lower.back(), CROSS_AISLE_BACK, CROSS_AISLE_HEIGHT
	)
	_shape.ring_wall(
		geometry,
		_materials["terracotta"],
		CROSS_AISLE_BACK,
		CROSS_AISLE_HEIGHT,
		SECOND_TIER_WALL_TOP,
		true,
		0.0
	)
	_shape.ring_floor(
		geometry,
		_materials["terracotta"],
		CROSS_AISLE_BACK,
		second.front,
		SECOND_TIER_WALL_TOP,
		true,
		0.0
	)
	_shape.ring_wall(
		geometry,
		_materials["terracotta"],
		second.front,
		second.height,
		SECOND_TIER_WALL_TOP,
		false,
		0.0
	)
	_build_rows(geometry, second)
	# Upper bowl behind its blue fascia, up to the rim
	_shape.ring_wall(
		geometry, _materials["fascia"], UPPER_FASCIA.x, UPPER_FASCIA.y, UPPER_FASCIA.z, true, 0.0
	)
	_shape.ring_floor(
		geometry, _materials["fascia"], UPPER_FASCIA.x, upper.front, UPPER_FASCIA.z, true, 0.0
	)
	_shape.ring_floor(
		geometry, _materials["fascia"], UPPER_FASCIA.x, SUITE_GLASS, UPPER_FASCIA.y, false, 0.0
	)
	_shape.ring_wall(
		geometry, _materials["fascia"], upper.front, upper.height, UPPER_FASCIA.z, false, 0.0
	)
	_build_rows(geometry, upper)
	_build_platforms(geometry)
	_shape.ring_wall(
		geometry,
		_materials["concrete"],
		upper.back(),
		upper.row_height(upper.rows - 1),
		RIM_WALKWAY.y,
		true
	)
	_shape.ring_floor(geometry, _materials["concrete"], upper.back(), RIM_WALKWAY.x, RIM_WALKWAY.y)
	_shape.ring_wall(
		geometry, _materials["concrete"], RIM_WALKWAY.x, RIM_WALKWAY.y, RIM_WALL_TOP, true
	)
	_shape.ring_floor(geometry, _materials["concrete"], RIM_WALKWAY.x, FACADE, RIM_WALL_TOP)
	return geometry


## The rows of a tier with their seats, and its aisles with their steps.
func _build_rows(geometry: FlatGeometry, tier: StadiumTier) -> void:
	for row in tier.rows:
		var front: float = tier.row_front(row)
		var height: float = tier.row_height(row)
		_shape.ring_floor(
			geometry, _materials["concrete"], front, front + tier.depth, height, true, 0.03
		)
		if row > 0:
			_shape.ring_wall(
				geometry,
				_materials["concrete"],
				front,
				tier.row_height(row - 1),
				height,
				true,
				0.03
			)
	for edge in _shape.edge_count():
		var aisles: PackedFloat32Array = _aisles(tier, edge)
		for t in aisles:
			if t > 0.0:
				_build_aisle(geometry, tier, edge, t)
		if _is_aisle_vertex(tier, edge):
			_build_aisle(geometry, tier, edge, 0.0)
		for row in tier.rows:
			_add_row_seats(tier, edge, row, aisles)


## Interior aisles of `edge` in `tier`, as shares along the edge (0 to 1).
func _aisles(tier: StadiumTier, edge: int) -> PackedFloat32Array:
	var aisles := PackedFloat32Array()
	if not tier.has_aisles:
		return aisles
	var sections: int = maxi(1, roundi(_shape.edge_length(edge, tier.middle()) / SECTION_LENGTH))
	for i in range(1, sections):
		aisles.append(float(i) / sections)
	return aisles


## Whether an aisle runs up the tier at vertex `vertex` (between two edges): between sections
## (every other facet of a corner), and at every facet where the corners get wide.
func _is_aisle_vertex(tier: StadiumTier, vertex: int) -> bool:
	if not tier.has_aisles:
		return false
	var facet: int = _shape.facet(vertex)
	return facet % 2 == 0 or facet == CORNER_FACETS or tier.middle() > 15.0


## Steps up an aisle at `t` along `edge` (0: at the edge's first vertex, between two edges).
func _build_aisle(geometry: FlatGeometry, tier: StadiumTier, edge: int, t: float) -> void:
	var left: Vector2 = (
		-_shape.directions[posmod(edge - 1, _shape.edge_count())]
		if t == 0.0
		else -_shape.directions[edge]
	)
	var right: Vector2 = _shape.directions[edge]
	for row in tier.rows:
		var front: float = tier.row_front(row)
		var middle: float = front + tier.depth * 0.5
		var back: float = front + tier.depth
		var bottom: float = tier.row_height(row)
		var step: float = (bottom + tier.row_height(row + 1)) * 0.5
		# Each row's floor in the aisle, and a half step at the back of it
		var sides: Array[Vector2] = [left, right]
		_aisle_strip(
			geometry,
			"step",
			edge,
			t,
			sides,
			Vector2(front, back),
			Vector2(bottom, bottom + 0.004),
			false
		)
		_aisle_strip(
			geometry, "step", edge, t, sides, Vector2(middle, back), Vector2(bottom, step), true
		)
		_aisle_strip(
			geometry,
			"nosing",
			edge,
			t,
			sides,
			Vector2(front, front + 0.05),
			Vector2(bottom + 0.004, bottom + 0.006),
			false
		)
		_aisle_strip(
			geometry,
			"nosing",
			edge,
			t,
			sides,
			Vector2(middle, middle + 0.05),
			Vector2(step, step + 0.002),
			false
		)


## A block in an aisle spanning offsets `span` and heights `heights`, reaching out to both
## `sides` of the aisle's middle line: its top, and its front (if `with_front`).
func _aisle_strip(
	geometry: FlatGeometry,
	material: String,
	edge: int,
	t: float,
	sides: Array[Vector2],
	span: Vector2,
	heights: Vector2,
	with_front: bool
) -> void:
	var from: float = span.x
	var to: float = span.y
	var bottom: float = heights.x
	var top: float = heights.y
	var half: float = AISLE_WIDTH * 0.5
	for side in sides:
		var near_center: Vector2 = _shape.on_edge(edge, t, from)
		var far_center: Vector2 = _shape.on_edge(edge, t, to)
		var near_side: Vector2 = near_center + side * half
		var far_side: Vector2 = far_center + side * half
		geometry.quad(
			_materials[material],
			Vector3(near_center.x, top, near_center.y),
			Vector3(near_side.x, top, near_side.y),
			Vector3(far_side.x, top, far_side.y),
			Vector3(far_center.x, top, far_center.y),
			Vector3.UP
		)
		if with_front:
			geometry.quad(
				_materials[material],
				Vector3(near_center.x, bottom, near_center.y),
				Vector3(near_side.x, bottom, near_side.y),
				Vector3(near_side.x, top, near_side.y),
				Vector3(near_center.x, top, near_center.y),
				-_shape.outward(edge),
				_shape.shade(0.03)
			)


## Seats of `row` along `edge`, leaving out the aisles (`aisles` inside the edge and the ones
## at its vertices) and the camera bays.
func _add_row_seats(tier: StadiumTier, edge: int, row: int, aisles: PackedFloat32Array) -> void:
	var d: float = tier.row_front(row) + tier.depth * SEAT_POSITION
	var length: float = _shape.edge_length(edge, d)
	var gaps: Array[Vector2] = []
	var vertex_gap: float = AISLE_WIDTH * 0.5 + SEAT_GAP
	gaps.append(Vector2(-1.0, vertex_gap if _is_aisle_vertex(tier, edge) else SEAT_GAP))
	gaps.append(
		Vector2(
			length - (vertex_gap if _is_aisle_vertex(tier, edge + 1) else SEAT_GAP), length + 1.0
		)
	)
	for t in aisles:
		gaps.append(Vector2(t * length - vertex_gap, t * length + vertex_gap))
	if not tier.has_aisles:
		for t in _partitions(edge, tier.middle()):
			gaps.append(Vector2(t * length - 0.2, t * length + 0.2))
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var section: String = "%s_%s" % [tier.name, _group(edge)]
	if not _sections.has(section):
		_sections[section] = PackedVector4Array()
	var height: float = tier.row_height(row)

	var facing: Vector3 = -_shape.outward(edge)
	var angle: float = atan2(facing.x, facing.z)
	for i in gaps.size() - 1:
		var free: float = gaps[i + 1].x - gaps[i].y
		var count: int = floori(free / SEAT_WIDTH)
		var start: float = gaps[i].y + (free - count * SEAT_WIDTH) * 0.5 + SEAT_WIDTH * 0.5
		for seat in count:
			var at: Vector2 = _shape.on_edge(edge, (start + seat * SEAT_WIDTH) / length, d)
			if tier == _tiers[0] and (_on_platform(at, d) or _behind_back_wall(at, height)):
				continue
			_sections[section].append(Vector4(at.x, height, at.y, angle))


## Whether a seat at `at` (x, z), on a floor `height` high, is hidden behind a wall behind a
## baseline, which reaches into the stands' corners (no one sits there).
func _behind_back_wall(at: Vector2, height: float) -> bool:
	return (
		absf(at.y) > FIELD_HALF_SIZE.y - 0.6
		and absf(at.x - FIELD_CENTER.x) < ArthurAsheCourtside.WALL_HALF_WIDTH + 0.4
		and height + 1.2 < ArthurAsheCourtside.BACK_WALL.x + 0.2
	)


## Group of seats `edge` belongs to: a straight side, or half a corner.
func _group(edge: int) -> String:
	var corner: int = posmod(edge, _shape.edge_count()) / (CORNER_FACETS + 1)
	if _shape.is_side(edge):
		return "side%d" % corner
	return "corner%d_%d" % [corner, _shape.facet(edge) * 2 / CORNER_FACETS]


## Whether a point at offset `d` in the lower tier is under a TV camera platform.
func _on_platform(at: Vector2, d: float) -> bool:
	return (
		absf(at.x) < PLATFORM_HALF_WIDTH + 0.3
		and absf(at.y) > FIELD_HALF_SIZE.y
		and d > LOWER_PLATFORM.x - 0.6
	)


## The TV camera platforms behind both baselines: two decks on posts, with railings around the
## back half, where the TV cameras' view stays clear of them.
func _build_platforms(geometry: FlatGeometry) -> void:
	for end: float in [1.0, -1.0]:
		for deck: Vector3 in [LOWER_PLATFORM, UPPER_PLATFORM]:
			var near: float = end * (FIELD_HALF_SIZE.y + deck.x)
			var far: float = end * (FIELD_HALF_SIZE.y + deck.y)
			var center := Vector3(0.0, deck.z - 0.1, (near + far) * 0.5)
			var size := Vector3(PLATFORM_HALF_WIDTH * 2.0, 0.2, absf(far - near))
			geometry.box(_materials["dark_steel"], Transform3D(Basis(), center), size)
			for x: float in [-PLATFORM_HALF_WIDTH + 0.1, 0.0, PLATFORM_HALF_WIDTH - 0.1]:
				for z: float in [near + end * 0.1, far - end * 0.1]:
					geometry.beam(
						_materials["dark_steel"],
						Vector3(x, 0.0, z),
						Vector3(x, deck.z - 0.2, z),
						0.12
					)
			var middle: float = (near + far) * 0.5
			var corners: Array[Vector3] = [
				Vector3(-PLATFORM_HALF_WIDTH, deck.z, middle),
				Vector3(-PLATFORM_HALF_WIDTH, deck.z, far),
				Vector3(PLATFORM_HALF_WIDTH, deck.z, far),
				Vector3(PLATFORM_HALF_WIDTH, deck.z, middle)
			]
			for i in 3:
				_railing(geometry, corners[i], corners[i + 1])


func _railing(geometry: FlatGeometry, from: Vector3, to: Vector3) -> void:
	var height: float = 1.05
	geometry.beam(_materials["steel"], from + Vector3.UP * height, to + Vector3.UP * height, 0.05)
	geometry.beam(
		_materials["steel"], from + Vector3.UP * height * 0.5, to + Vector3.UP * height * 0.5, 0.03
	)
	var posts: int = maxi(1, ceili(from.distance_to(to) / 1.2))
	for i in posts + 1:
		var at: Vector3 = from.lerp(to, float(i) / posts)
		geometry.beam(_materials["steel"], at, at + Vector3.UP * height, 0.045)


# --- Suites ------------------------------------------------------------------------------------


func _build_suites() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var second: StadiumTier = _tiers[1]
	var lower_suites: StadiumTier = _tiers[2]
	var upper_suites: StadiumTier = _tiers[3]
	# Front of the lower suites' balconies, behind the second tier
	_shape.ring_wall(
		geometry,
		_materials["fascia"],
		LOWER_SUITE_FRONT.x,
		second.row_height(second.rows - 1),
		LOWER_SUITE_FRONT.z,
		true,
		0.0
	)
	_shape.ring_floor(
		geometry,
		_materials["fascia"],
		LOWER_SUITE_FRONT.x,
		lower_suites.front,
		LOWER_SUITE_FRONT.z,
		true,
		0.0
	)
	_shape.ring_wall(
		geometry,
		_materials["fascia"],
		lower_suites.front,
		lower_suites.height,
		LOWER_SUITE_FRONT.z,
		false,
		0.0
	)
	# Blue fascia between the two suite rings, with the LED ribbon along its top
	_shape.ring_wall(
		geometry,
		_materials["fascia"],
		SUITE_FASCIA.x,
		SUITE_FASCIA.y,
		SUITE_FASCIA.z - RIBBON_HEIGHT,
		true,
		0.0
	)
	_shape.ring_wall(
		geometry,
		_materials["ribbon"],
		SUITE_FASCIA.x,
		SUITE_FASCIA.z - RIBBON_HEIGHT,
		SUITE_FASCIA.z,
		true,
		0.0
	)
	_shape.ring_floor(
		geometry,
		_materials["fascia"],
		SUITE_FASCIA.x,
		upper_suites.front,
		SUITE_FASCIA.z,
		true,
		0.0
	)
	_shape.ring_wall(
		geometry,
		_materials["fascia"],
		upper_suites.front,
		upper_suites.height,
		SUITE_FASCIA.z,
		false,
		0.0
	)
	_shape.ring_floor(
		geometry, _materials["partition"], SUITE_FASCIA.x, SUITE_GLASS, SUITE_FASCIA.y, false, 0.0
	)
	for tier: StadiumTier in [lower_suites, upper_suites]:
		for row in tier.rows:
			var front: float = tier.row_front(row)
			_shape.ring_floor(
				geometry,
				_materials["concrete"],
				front,
				front + tier.depth,
				tier.row_height(row),
				true,
				0.02
			)
			if row > 0:
				_shape.ring_wall(
					geometry,
					_materials["concrete"],
					front,
					tier.row_height(row - 1),
					tier.row_height(row),
					true,
					0.02
				)
		var ceiling: float = SUITE_FASCIA.y if tier == lower_suites else UPPER_FASCIA.y
		_shape.ring_wall(geometry, _materials["glass"], SUITE_GLASS, tier.top, ceiling, true, 0.05)
		for edge in _shape.edge_count():
			# Window mullions, and partitions between the suites' balconies
			var mullions: int = maxi(1, roundi(_shape.edge_length(edge, SUITE_GLASS) / 1.6))
			for i in mullions:
				var at: Vector2 = _shape.on_edge(edge, float(i) / mullions, SUITE_GLASS - 0.03)
				geometry.beam(
					_materials["dark_steel"],
					Vector3(at.x, tier.top, at.y),
					Vector3(at.x, ceiling, at.y),
					0.07
				)
			for t in _partitions(edge, tier.middle()):
				var near: Vector2 = _shape.on_edge(edge, t, tier.front)
				var far: Vector2 = _shape.on_edge(edge, t, SUITE_GLASS)
				geometry.wall(
					_materials["partition"],
					Vector3(near.x, tier.height, near.y),
					Vector3(far.x, tier.height, far.y),
					0.08,
					1.45
				)
			for row in tier.rows:
				_add_row_seats(tier, edge, row, PackedFloat32Array())
	return geometry


## Partitions between suites along `edge` at offset `d`, as shares along the edge.
func _partitions(edge: int, d: float) -> PackedFloat32Array:
	var partitions := PackedFloat32Array()
	var suites: int = maxi(1, roundi(_shape.edge_length(edge, d) / SUITE_LENGTH))
	for i in suites:
		partitions.append(float(i) / suites)
	return partitions


# --- Facade ------------------------------------------------------------------------------------


func _build_facade() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	# Brick with bands of windows at the concourses
	var bands: Array[Vector3] = [
		Vector3(0.0, 2.6, 0.0),
		Vector3(2.6, 5.4, 1.0),
		Vector3(5.4, 10.6, 0.0),
		Vector3(10.6, 13.4, 1.0),
		Vector3(13.4, 18.8, 0.0),
		Vector3(18.8, 21.2, 1.0),
		Vector3(21.2, RIM_WALL_TOP, 0.0)
	]
	var along: float = 0.0
	for edge in _shape.edge_count():
		var a: Vector2 = _shape.at(edge, FACADE)
		var b: Vector2 = _shape.at(edge + 1, FACADE)
		var length: float = a.distance_to(b)
		for band in bands:
			var corners := PackedVector3Array(
				[
					Vector3(a.x, band.x, a.y),
					Vector3(b.x, band.x, b.y),
					Vector3(b.x, band.y, b.y),
					Vector3(a.x, band.y, a.y)
				]
			)
			var uvs := PackedVector2Array(
				[
					Vector2(along, band.x),
					Vector2(along + length, band.x),
					Vector2(along + length, band.y),
					Vector2(along, band.y)
				]
			)
			geometry.polygon(
				_materials["glass" if band.z > 0.5 else "brick"],
				corners,
				_shape.outward(edge),
				Color.WHITE,
				uvs
			)
		# Piers between the windows and a cornice on top
		var piers: int = maxi(1, roundi(length / 4.0))
		for i in piers:
			var at: Vector2 = a.lerp(b, float(i) / piers) + _shape.normals[edge] * 0.2
			geometry.box(
				_materials["terracotta"],
				Transform3D(StadiumShape.facing(_shape.normals[edge]), Vector3(at.x, 11.0, at.y)),
				Vector3(0.6, 22.0, 0.4)
			)
		along += length
	_shape.ring_wall(
		geometry,
		_materials["concrete"],
		FACADE + 0.5,
		RIM_WALL_TOP - 0.8,
		RIM_WALL_TOP + 0.3,
		false,
		0.0
	)
	_shape.ring_floor(
		geometry, _materials["concrete"], FACADE, FACADE + 0.5, RIM_WALL_TOP + 0.3, true, 0.0
	)
	_shape.ring_floor(
		geometry, _materials["concrete"], FACADE, FACADE + 0.5, RIM_WALL_TOP - 0.8, false, 0.0
	)
	# Gates with canopies in the middle of every side
	for edge in _shape.edge_count():
		if not _shape.is_side(edge):
			continue
		var middle: Vector2 = _shape.on_edge(edge, 0.5, FACADE + 0.02)
		var across: Vector2 = _shape.directions[edge]
		var out: Vector2 = _shape.normals[edge]
		var half: float = 7.0
		var p0: Vector2 = middle - across * half
		var p1: Vector2 = middle + across * half
		geometry.quad(
			_materials["black"],
			Vector3(p0.x, 0.0, p0.y),
			Vector3(p1.x, 0.0, p1.y),
			Vector3(p1.x, 5.5, p1.y),
			Vector3(p0.x, 5.5, p0.y),
			_shape.outward(edge)
		)
		var canopy: Vector2 = middle + out * 3.0
		geometry.box(
			_materials["steel"],
			Transform3D(StadiumShape.facing(out), Vector3(canopy.x, 6.2, canopy.y)),
			Vector3(half * 2.0 + 4.0, 0.35, 6.0)
		)
	return geometry


# --- Seats -------------------------------------------------------------------------------------


func _make_seat_mesh() -> ArrayMesh:
	var geometry := FlatGeometry.new()
	var seat: Material = _materials["seat"]
	var frame: Material = _materials["seat_frame"]
	geometry.box(
		seat,
		Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0.0, 0.43, 0.03)),
		Vector3(0.46, 0.05, 0.4)
	)
	geometry.box(
		seat,
		Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0.0, 0.7, -0.2)),
		Vector3(0.46, 0.44, 0.05)
	)
	geometry.box(frame, Transform3D(Basis(), Vector3(-0.255, 0.3, -0.05)), Vector3(0.04, 0.6, 0.36))
	geometry.box(
		frame, Transform3D(Basis(), Vector3(-0.255, 0.62, 0.04)), Vector3(0.06, 0.04, 0.36)
	)
	var mesh: ArrayMesh = geometry.to_mesh()
	_save(mesh, MESH_DIR + "seat.res")
	return mesh


func _add_seats() -> void:
	var seating := StadiumSeating.new()
	var names: Array[String] = _sections.keys()
	names.sort()
	var total: int = 0
	for section in names:
		seating.sections.append(_sections[section])
		total += _sections[section].size()
	_save(seating, SEATING_PATH)
	var seats := StadiumSeats.new()
	seats.name = "Seats"
	seats.seating = seating
	seats.seat_mesh = _seat_mesh
	_add(_root, seats)
	print("Seats: %d in %d sections" % [total, seating.sections.size()])


# --- Boards, flag, signs, cameras --------------------------------------------------------------


## The sponsors' logos on the suites' fascias and the upper bowl's, and the lettering on the
## facade. Each fascia shows its logos in turn, spread along every edge.
func _build_logos() -> FlatGeometry:
	var geometry := FlatGeometry.new()
	var fascias: Array[Array] = [
		[LOWER_SUITE_FRONT, 0.42, LOWER_SUITE_LOGOS],
		[Vector3(SUITE_FASCIA.x, SUITE_FASCIA.y, SUITE_FASCIA.z - RIBBON_HEIGHT), 0.5, SUITE_LOGOS],
		[UPPER_FASCIA, 0.7, UPPER_LOGOS],
	]
	for fascia in fascias:
		var place: Vector3 = fascia[0]
		var logos: Array[StringName] = fascia[2]
		var next: int = 0
		for edge in _shape.edge_count():
			var count: int = maxi(
				1, floori(_shape.edge_length(edge, place.x) / FASCIA_LOGO_SPACING)
			)
			for i in count:
				var at: Vector2 = _shape.on_edge(edge, (i + 0.5) / count, place.x - 0.015)
				UsOpenLogos.add(
					geometry,
					_materials["logos"],
					logos[next % logos.size()],
					Vector3(at.x, (place.y + place.z) * 0.5, at.y),
					-_shape.outward(edge),
					fascia[1]
				)
				next += 1
	for edge in _shape.edge_count():
		if _shape.is_long_side(edge):
			var at: Vector2 = _shape.on_edge(edge, 0.5, CROSS_AISLE_BACK - 0.015)
			UsOpenLogos.add(
				geometry,
				_materials["logos"],
				&"arthur_ashe_stadium",
				Vector3(at.x, (CROSS_AISLE_HEIGHT + SECOND_TIER_WALL_TOP) * 0.5, at.y),
				-_shape.outward(edge),
				0.4
			)
		elif _shape.is_side(edge):
			for logo: Array in [[&"arthur_ashe_stadium", 27.0, 1.6], [&"us_open", 8.5, 2.2]]:
				var at: Vector2 = _shape.on_edge(edge, 0.5, FACADE + 0.25)
				UsOpenLogos.add(
					geometry,
					_materials["logos"],
					logo[0],
					Vector3(at.x, logo[1], at.y),
					_shape.outward(edge),
					logo[2]
				)
	return geometry


# --- Saving ------------------------------------------------------------------------------------


func _add_mesh(parent: Node3D, mesh_name: String, geometry: FlatGeometry) -> void:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = geometry.to_mesh()
	_save(instance.mesh, MESH_DIR + mesh_name.to_snake_case() + ".res")
	_add(parent, instance)


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = _root


func _save(resource: Resource, path: String) -> void:
	ResourceSaver.save(resource, path, ResourceSaver.FLAG_COMPRESS)
	resource.take_over_path(path)
