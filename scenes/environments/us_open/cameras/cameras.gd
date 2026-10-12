## Broadcast and debug cameras of the match; 1 cycles through them. The TV and courtside cameras
## among them move like real broadcast cameras (see TvCamera and CourtsideCamera).
## The camera picked (by cycling or in the debug HUD) stays picked until another is picked. While
## the view is behind a human player (see show_from_behind), a camera that has a twin on the other
## end of the court, or a player's own view, is shown from that player's end or through their
## eyes, also after they change ends.
## Between points of a broadcast match the director cuts away from the picked camera now and
## then, like a real tennis broadcast (see cover_point_break).
class_name MatchCameras
extends Node3D

## Shots the director cuts to between points
enum Shot { PICKED, WINNER_CLOSE_UP, LOSER_CLOSE_UP, CROWD, AERIAL }

## Seconds the picked camera stays on after a point before the first cutaway (shortest, longest)
const REACTION_HOLD: Vector2 = Vector2(1.2, 2.2)
## Seconds a cutaway lasts (shortest, longest); none shorter than the shortest is cut to
const CUTAWAY_LENGTH: Vector2 = Vector2(2.5, 4.5)
## Seconds the picked camera is back on before the break ends, so the players are seen getting
## ready for the next point
const RETURN_LEAD: float = 2.0
## Weight of each shot as a cutaway after the calmest and the most exciting point (see
## _pick_cutaway); the aerial shot after a game is more likely
const CALM_WEIGHTS: Dictionary[Shot, float] = {
	Shot.PICKED: 0.8,
	Shot.WINNER_CLOSE_UP: 1.0,
	Shot.LOSER_CLOSE_UP: 0.3,
	Shot.CROWD: 0.2,
	Shot.AERIAL: 0.04,
}
const EXCITED_WEIGHTS: Dictionary[Shot, float] = {
	Shot.PICKED: 0.15,
	Shot.WINNER_CLOSE_UP: 1.6,
	Shot.LOSER_CLOSE_UP: 0.6,
	Shot.CROWD: 1.0,
	Shot.AERIAL: 0.04,
}
const AERIAL_WEIGHT_AFTER_GAME: float = 0.2
## Weight of going back to the picked camera after the first cutaway: one or two cutaways a break
const RETURN_WEIGHT: float = 1.2
## Weight factor of the shot the previous break opened with, so breaks do not look alike
const REPEAT_FACTOR: float = 0.35
## Breaks after an aerial shot before the next can be shown
const AERIAL_COOLDOWN: int = 6

@export var cams: Array[Camera3D]
## Camera active at the start, and picked
@export var active_cam: Camera3D
## Cameras showing the court from the front end (z > 0) and, at the same index, their twins
## showing it from the back end (z < 0)
@export var front_end_cams: Array[Camera3D]
@export var back_end_cams: Array[Camera3D]
## Cameras the director cuts away to between points: close-ups of the player on the front and on
## the back half of the court, the crowd and the stadium from above
@export var front_close_up_cam: PlayerCloseUpCamera
@export var back_close_up_cam: PlayerCloseUpCamera
@export var crowd_cam: CrowdShotCamera
@export var aerial_cam: AerialCamera

## Camera picked to watch the match with
var _picked: Camera3D
## Human player the view is behind, null if none
var _viewer: Player
## Each player's own view (see register_player_view)
var _player_views: Dictionary[Player, Camera3D] = {}
## Number of breaks covered so far and picks made; a break's cutaways stop when a newer break
## starts or a camera is picked
var _break_count: int = 0
## Shot the previous break opened with, and breaks since the last aerial shot
var _last_opening: Shot = Shot.PICKED
var _breaks_since_aerial: int = AERIAL_COOLDOWN


func _ready() -> void:
	_picked = active_cam
	activate(active_cam)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_1:
		_pick_next()


## Adds `player`'s own view to the cameras.
func register_player_view(player: Player) -> void:
	_player_views[player] = player.first_person_camera
	cams.append(player.first_person_camera)


## Makes `camera` the picked one, showing it from the viewer's end.
func pick(camera: Camera3D) -> void:
	_picked = camera
	_break_count += 1
	activate(_for_viewer(camera))


func activate(camera: Camera3D) -> void:
	active_cam = camera
	camera.make_current()


## Puts the view behind the human `player`: the picked camera, from their end of the court.
func show_from_behind(player: Player) -> void:
	_viewer = player
	activate(_for_viewer(_picked))


## Starts the match broadcast: the active TV camera slowly zooms in.
func open_match() -> void:
	if active_cam is TvCamera:
		(active_cam as TvCamera).open_shot()


## Points the courtside cameras at the player on their end of the court.
func track_players(front_player: Player, back_player: Player) -> void:
	for camera in cams:
		if camera is CourtsideCamera:
			var front: bool = camera.global_position.z > 0.0
			(camera as CourtsideCamera).follow(front_player if front else back_player)


## Between points the TV cameras now and then reframe slightly.
func reframe_tv_cameras() -> void:
	for camera in cams:
		if camera is TvCamera:
			(camera as TvCamera).reframe()


## Before a serve the TV cameras on the returner's end widen to keep the returner in the picture.
func frame_return(receiver: Player) -> void:
	for camera in cams:
		if camera is TvCamera:
			(camera as TvCamera).frame_return(receiver)


## After the serve the TV cameras settle back to their standard shot.
func settle_after_serve() -> void:
	for camera in cams:
		if camera is TvCamera:
			(camera as TvCamera).settle_after_serve()


## Covers the `duration` seconds break after a point `winner` won like a real tennis broadcast,
## returning when it is over, with the picked camera on. The picked camera stays on while the
## players react; then the director may cut away, more often and to the players and the crowd
## the more `excitement` (0 to 1) the point had, and now and then to the stadium from above,
## more likely when the point ended a game (`game_ended`). The picked camera is back on shortly
## before the break ends. Picking a camera ends the cutaways.
func cover_point_break(
	duration: float, winner: Player, excitement: float, game_ended: bool
) -> void:
	_break_count += 1
	var break_number: int = _break_count
	_breaks_since_aerial += 1
	var time_left: float = duration
	var hold: float = minf(randf_range(REACTION_HOLD.x, REACTION_HOLD.y), time_left)
	await _wait(hold)
	time_left -= hold
	var shown: Array[Shot] = []
	while break_number == _break_count and time_left - RETURN_LEAD >= CUTAWAY_LENGTH.x:
		var shot: Shot = _pick_cutaway(shown, excitement, game_ended)
		if shown.is_empty():
			_last_opening = shot
		if shot == Shot.PICKED:
			break
		shown.append(shot)
		_cut_to(shot, winner)
		var length: float = minf(
			randf_range(CUTAWAY_LENGTH.x, CUTAWAY_LENGTH.y), time_left - RETURN_LEAD
		)
		await _wait(length)
		time_left -= length
	if break_number == _break_count:
		activate(_for_viewer(_picked))
	await _wait(time_left)


## The next cutaway, by the weights of the shots for the point: none (PICKED) or a shot not
## `shown` yet in this break.
func _pick_cutaway(shown: Array[Shot], excitement: float, game_ended: bool) -> Shot:
	var weights: Dictionary[Shot, float] = {}
	for shot: Shot in CALM_WEIGHTS:
		if shot in shown:
			continue
		weights[shot] = lerpf(CALM_WEIGHTS[shot], EXCITED_WEIGHTS[shot], excitement)
	if game_ended:
		weights[Shot.AERIAL] = AERIAL_WEIGHT_AFTER_GAME
	if _breaks_since_aerial <= AERIAL_COOLDOWN or Shot.AERIAL in shown:
		weights.erase(Shot.AERIAL)
	if shown.is_empty() and weights.has(_last_opening):
		weights[_last_opening] *= REPEAT_FACTOR
	else:
		weights[Shot.PICKED] = RETURN_WEIGHT

	var total: float = 0.0
	for weight in weights.values():
		total += weight
	var roll: float = randf() * total
	for shot: Shot in weights:
		roll -= weights[shot]
		if roll <= 0.0:
			return shot
	return Shot.PICKED


func _cut_to(shot: Shot, winner: Player) -> void:
	match shot:
		Shot.WINNER_CLOSE_UP:
			_cut_to_close_up(winner)
		Shot.LOSER_CLOSE_UP:
			_cut_to_close_up(winner.opponent)
		Shot.CROWD:
			crowd_cam.frame_spectators()
			activate(crowd_cam)
		Shot.AERIAL:
			_breaks_since_aerial = 0
			aerial_cam.frame_stadium()
			activate(aerial_cam)


## Cuts to a close-up of `player` from the camera on their end of the court.
func _cut_to_close_up(player: Player) -> void:
	var camera: PlayerCloseUpCamera = (
		front_close_up_cam if player.global_position.z > 0.0 else back_close_up_cam
	)
	camera.frame(player)
	activate(camera)


## `camera` as the viewer sees it: its twin on the viewer's end of the court, or the viewer's own
## view for a player's view. Without a viewer, and for cameras without a twin, `camera` itself.
func _for_viewer(camera: Camera3D) -> Camera3D:
	if not _viewer:
		return camera
	if camera in _player_views.values():
		return _player_views[_viewer]
	var pair: int = maxi(front_end_cams.find(camera), back_end_cams.find(camera))
	if pair == -1:
		return camera
	return front_end_cams[pair] if _viewer.global_position.z > 0.0 else back_end_cams[pair]


## Picks the next camera after the active one that changes the view.
func _pick_next() -> void:
	var index: int = cams.find(active_cam)
	for step in range(1, cams.size()):
		var camera: Camera3D = cams[(index + step) % cams.size()]
		if _for_viewer(camera) != active_cam:
			pick(camera)
			return


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
