## Camera of the menu background, directed like a live tennis broadcast: it cuts between shots, one
## after the other in random order, each a slow move through the stadium. There is an airship
## shot high above, a crane rising from the baseline, a tracking shot along the sideline, a
## skycam gliding down the court, close shots of the bench and long lens pans over the crowd.
## The court is centered on the origin and its length runs along Z (see Stadium). The menu opens
## with the main camera behind the baseline slowly zooming in, the shots after it are random.
class_name MenuCameraDirector
extends Camera3D


## One shot: the camera moves from `from_position` to `to_position` looking at `from_focus`
## moving to `to_focus`, its field of view widening or narrowing from `from_fov` to `to_fov`,
## over `duration` seconds.
class Shot:
	var name: String
	var from_position: Vector3
	var to_position: Vector3
	var from_focus: Vector3
	var to_focus: Vector3
	var from_fov: float
	var to_fov: float
	var duration: float

	func _init(
		shot_name: String,
		positions: Array[Vector3],
		focuses: Array[Vector3],
		fovs: Vector2,
		shot_duration: float
	) -> void:
		name = shot_name
		from_position = positions[0]
		to_position = positions[1]
		from_focus = focuses[0]
		to_focus = focuses[1]
		from_fov = fovs.x
		to_fov = fovs.y
		duration = shot_duration


## How much of the move's ease (slow start and end of a camera operator's move) is applied
const EASE: float = 0.6

var _shots: Array[Shot] = []
## Shots still to show before they are shuffled again
var _queue: Array[Shot] = []
var _shot: Shot
var _shot_time: float = 0.0


func _ready() -> void:
	# The stadium's own cameras take over when it is ready, which is before this camera is.
	make_current()
	_shots = _build_shots()
	_start_shot(_shots[0])


func _process(delta: float) -> void:
	_shot_time += delta
	if _shot_time >= _shot.duration:
		_next_shot()
	apply(_shot, _shot_time / _shot.duration)


## Puts the camera where `shot` has it `progress` (0 to 1) of the way through.
func apply(shot: Shot, progress: float) -> void:
	var eased: float = lerpf(progress, smoothstep(0.0, 1.0, progress), EASE)
	global_position = shot.from_position.lerp(shot.to_position, eased)
	fov = lerpf(shot.from_fov, shot.to_fov, eased)
	look_at(shot.from_focus.lerp(shot.to_focus, eased), Vector3.UP)


func get_shots() -> Array[Shot]:
	return _shots


## Cuts to the next shot: the shots in random order, none twice in a row.
func _next_shot() -> void:
	if _queue.is_empty():
		_queue = _shots.duplicate()
		_queue.shuffle()
		if _queue.back() == _shot:
			_queue.reverse()
	_start_shot(_queue.pop_back())


func _start_shot(shot: Shot) -> void:
	_shot = shot
	_shot_time = 0.0
	apply(_shot, 0.0)


## The shots, the one the menu opens with first.
func _build_shots() -> Array[Shot]:
	return [
		# The main camera behind the baseline, slowly zooming in on the court
		Shot.new(
			"Main camera",
			[Vector3(0, 9.9, 32.2), Vector3(0, 9.9, 32.2)],
			[Vector3(0, 1.0, 0), Vector3(0, 1.0, -2)],
			Vector2(27, 21),
			11.0
		),
		# The airship: high above, sweeping over the stadium with the court in the middle
		Shot.new(
			"Airship",
			[Vector3(-26, 62, 38), Vector3(26, 50, 30)],
			[Vector3(0, 0, 0), Vector3(0, 0, -4)],
			Vector2(42, 42),
			16.0
		),
		# A crane at the baseline rising from the court's level over the court
		Shot.new(
			"Crane",
			[Vector3(-3, 0.8, 16.5), Vector3(3, 3.6, 17.5)],
			[Vector3(0, 0.6, 6), Vector3(0, 4.0, -20)],
			Vector2(55, 48),
			12.0
		),
		# A tracking shot along the sideline, from one baseline to the other
		Shot.new(
			"Sideline",
			[Vector3(10.5, 1.5, 15), Vector3(10.5, 1.5, -13)],
			[Vector3(0, 1.0, 8), Vector3(0, 1.0, -8)],
			Vector2(38, 38),
			14.0
		),
		# The skycam gliding down the court above the net
		Shot.new(
			"Skycam",
			[Vector3(2.5, 8.5, 19), Vector3(2.5, 5.0, -5)],
			[Vector3(0, 1.0, -8), Vector3(0, 1.0, 6)],
			Vector2(50, 50),
			13.0
		),
		# The player's bench with its rackets and bag, the camera pushing in
		Shot.new(
			"Bench",
			[Vector3(-1.5, 2.2, 8.5), Vector3(-4.0, 1.6, 5.8)],
			[Vector3(-7.5, 0.7, 2.4), Vector3(-7.5, 0.7, 2.4)],
			Vector2(30, 24),
			9.0
		),
		# A long lens over the crowd on the far side
		Shot.new(
			"Crowd across",
			[Vector3(10, 2.5, -6), Vector3(10, 2.5, -6)],
			[Vector3(-22, 5.5, -14), Vector3(-22, 5.5, 8)],
			Vector2(20, 20),
			12.0
		),
		# The same from the other side, panning the other way
		Shot.new(
			"Crowd back",
			[Vector3(-11, 2.0, 6), Vector3(-11, 2.0, 6)],
			[Vector3(22, 5.0, 10), Vector3(22, 5.0, -10)],
			Vector2(20, 20),
			12.0
		),
	]
