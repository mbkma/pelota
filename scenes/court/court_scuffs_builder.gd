## Draws the scuff marks the players' shoes leave on the court's paint into SCUFFS_PATH, a
## seamless texture TILE_SIZE m across (see hard_court.gdshader): thin curved streaks, sharp in
## the middle and fading out at both ends, where a sole slid and turned. Run it after changing it:
##
##     godot --headless --path . -s res://scenes/court/court_scuffs_builder.gd
class_name CourtScuffsBuilder
extends SceneTree

const SCUFFS_PATH: String = "res://assets/textures/court/court_scuffs.png"
## Pixels across the texture, and the meters it covers
const SIZE: int = 2048
const TILE_SIZE: float = 6.0
## Marks in the texture
const MARKS: int = 1200
## Length (m) and width (m, in the middle) of a mark
const LENGTH: Vector2 = Vector2(0.12, 0.9)
const WIDTH: Vector2 = Vector2(0.004, 0.018)
## Share of the marks that are smears instead: this much wider, and fainter
const SMEARS: float = 0.2
const SMEAR_WIDTH: float = 3.0
const SMEAR_STRENGTH: float = 0.35
## How much a mark's heading turns (rad per m), and how much that changes along it, so marks
## curve and sometimes bend into an S or hook
const TURN: float = 2.5
const TURN_CHANGE: float = 12.0


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	# Let the project's autoloads start up first: quitting before they have does not end the run.
	for frame in 10:
		await process_frame
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var marks := PackedFloat32Array()
	marks.resize(SIZE * SIZE)
	for mark in MARKS:
		_draw_mark(marks, random)
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var value: float = marks[y * SIZE + x]
			image.set_pixel(x, y, Color(value, value, value))
	DirAccess.make_dir_recursive_absolute(SCUFFS_PATH.get_base_dir())
	var error: Error = image.save_png(SCUFFS_PATH)
	assert(error == OK, "Could not save %s: %s" % [SCUFFS_PATH, error_string(error)])
	print("saved ", SCUFFS_PATH)
	quit()


## Draws one mark into `marks` at a random place, keeping the brightest where marks cross.
func _draw_mark(marks: PackedFloat32Array, random: RandomNumberGenerator) -> void:
	var pixels_per_meter: float = SIZE / TILE_SIZE
	var length: float = lerpf(LENGTH.x, LENGTH.y, random.randf() ** 2.0) * pixels_per_meter
	var width: float = random.randf_range(WIDTH.x, WIDTH.y) * pixels_per_meter * 0.5
	var strength: float = random.randf_range(0.35, 1.0)
	if random.randf() < SMEARS:
		width *= SMEAR_WIDTH
		strength *= SMEAR_STRENGTH
	var at := Vector2(random.randf(), random.randf()) * SIZE
	var heading: float = random.randf() * TAU
	var turn: float = random.randf_range(-TURN, TURN) / pixels_per_meter
	var turn_change: float = TURN_CHANGE / pixels_per_meter / pixels_per_meter
	var steps: int = ceili(length)
	for step in steps:
		var along: float = float(step) / steps
		# Thin and faint at both ends
		var fade: float = sin(along * PI) ** 0.7
		_stamp(marks, at, maxf(width * fade, 0.6), strength * fade)
		heading += turn
		turn += random.randf_range(-turn_change, turn_change)
		at += Vector2.from_angle(heading)


## A round dot of `radius` px at `center`, soft towards its edge, wrapping around the
## texture's edges.
func _stamp(marks: PackedFloat32Array, center: Vector2, radius: float, strength: float) -> void:
	var reach: int = ceili(radius + 1.0)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var x: int = floori(center.x) + dx
			var y: int = floori(center.y) + dy
			var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			var value: float = (
				strength * clampf((radius + 0.5 - distance) / (radius * 0.6 + 0.5), 0.0, 1.0)
			)
			if value <= 0.0:
				continue
			var i: int = posmod(y, SIZE) * SIZE + posmod(x, SIZE)
			marks[i] = maxf(marks[i], value)
