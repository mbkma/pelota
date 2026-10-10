## Human player controller: maps one InputDevice to movement, aiming and strokes.
##
## Rally: the direction moves the player. Pressing a stroke button commits to a shot: the
## player runs to the incoming ball on its own, the direction aims inside the opponent's
## court until the racket meets the ball and holding the button charges power.
## Releasing the button times the shot: the closer to contact, the smaller the area the ball
## may land in and the more of the shot's attack pace it gets. Releasing within the perfect
## window before contact is a perfect shot, which stands out with the full pace, spin and
## precision; still holding at contact plays a weak, safe ball short through the middle.
## Pace: every shot has a rally speed (ATP averages: forehand ~115 km/h, backhand ~105 km/h)
## and an attack pace on top (winners up to ~165 km/h) that only comes through in full when
## the shot is perfectly timed, met in position and the player was set early with time to
## spare (see Player).
## Serve: before the serve the direction slides the server along the baseline. Pressing and
## holding a serve button picks the serve (STRIKE flat, SLICE slice, DROP_SHOT kick) and
## locks the server in place; the direction aims inside the service box for as long as the
## button is held. Releasing tosses the ball. Pressing any serve button again right before
## the racket meets the ball times the serve: the closer to contact, the faster and more
## precise it is. A serve that is not timed is weak and imprecise. A perfectly timed flat first
## serve of an average server goes ~112 mph (ATP average first serve: ~118 mph, second
## serve: ~95 mph). The server stays locked
## until the ball is hit.
## Directions follow the screen: up on the stick points up in the camera view this player is
## seen through, whichever end of the court the player is on.
## The direction sets an aim goal per axis that is kept while the direction eases back
## toward neutral; the aim moves toward that goal at AIM_SPEED. The aim only resets to the
## middle after this player hits the ball, a new serve, or the end of the point.
## The aim marker shows the landing area: every shot draws one random direction inside it,
## and the ball lands at the aim plus that direction times the current radius.
## Positioning: after the stroke button is pressed the player only shuffles toward the ball at
## SHOT_ADJUST_SPEED, so getting into position beforehand matters; a ball met off the racket's
## sweet spot loses pace and accuracy (see Player). The player decides how early to take a
## groundstroke (see ContactWindow) by where it stands: it meets the ball at the point of the
## contact window closest to it, so stepping in takes the ball early on the rise (more pace but
## harder to time) and staying back takes it late (safer but weaker). A marker shows the standard
## position to meet the opponent's ball and the range from the earliest to the latest contact,
## placed once from its real flight when the opponent hits it (only then is the shot decided)
## and kept until this player hits the ball. Its color shows how well the player stands in the
## range, red when far off to green when in place.
## A ball taken out of the air is volleyed; in the net zone the player steps in to cut it off
## before the bounce. A volley is a short punch: holding the button charges nothing, its pace
## is mostly the incoming pace sent back, and only a ball above the net can be put away (see
## Player). The drop shot button plays a drop volley.
## Player stats shape all of it: shot side and volley skill set the stroke speed, spin skills
## the spin, timing widens the perfect windows, and precision (shot control, return skill,
## net game, serve accuracy, all reduced by pressure) shrinks the landing area.
class_name HumanController
extends Controller

enum Mode {
	## The direction moves the player.
	FREE,
	## A stroke button was pressed: auto-positioning to the ball, the direction aims.
	SHOT,
	## Waiting to serve: the direction slides the server along the baseline.
	SERVE_READY,
	## Serve button held: server locked, the direction aims into the service box.
	SERVE_AIM,
	## Serve button released: toss and swing; a press near contact times the serve.
	SERVE_SWING,
}

enum ServeType {
	FLAT,
	SLICE,
	KICK,
}

## Seconds a stroke button has to be held for the full attack pace.
const FULL_CHARGE_TIME: float = 0.8
## How fast the aim moves toward its goal, in aim ranges (center to line) per second.
const AIM_SPEED: float = 1.4
## Direction axis values below this count as neutral for aiming.
const AIM_NEUTRAL: float = 0.05
## An aim axis only follows the direction while it stays above this share of the push's peak,
## so the aim holds while the stick springs back.
const AIM_RELEASE_RATIO: float = 0.9
## How far ahead (m) the slide target along the baseline lies; sets the slide speed.
const SERVE_SLIDE_LOOKAHEAD: float = 1.1
## Closest the server may stand to the center mark (m).
const SERVE_CENTER_MARGIN: float = 0.3
## Aim targets stay this far inside the lines (m).
const AIM_LINE_MARGIN: float = 0.5
## Speed factor of the automatic adjustment toward the ball once a stroke button is pressed;
## the player has to get into position on their own to arrive in time and set.
const SHOT_ADJUST_SPEED: float = 0.75
## Depth range (m from the net) of drop shot targets.
const DROP_SHOT_DEPTH_MIN: float = 1.5
const DROP_SHOT_DEPTH_MAX: float = 4.0

## Releasing the stroke button at most this many seconds before contact is perfect timing
## (for a player with average timing at the standard contact; the timing stat scales it).
const PERFECT_TIMING_WINDOW: float = 0.12
## Scale of the perfect window for a ball taken at the early end of the contact window (on the
## rise it is harder to time) and at its late end.
const EARLY_CONTACT_TIMING_WINDOW: float = 0.6
const LATE_CONTACT_TIMING_WINDOW: float = 1.25
## Releasing this many seconds or more before contact is the worst timing.
const EARLIEST_TIMING: float = 0.8
## Effects of the timing below perfect, from the worst timing to just outside the perfect
## window, and of perfect timing: a perfect shot gets its full rally speed and attack pace and
## clearly more spin (well-timed topspin dips and kicks more, slices skid lower and drop shots
## die after the bounce).
const TIMING_SPEED: Vector2 = Vector2(0.8, 0.92)
const TIMING_ATTACK: Vector2 = Vector2(0.0, 0.5)
const TIMING_SPIN: Vector2 = Vector2(0.85, 1.05)
const TIMING_SPIN_PERFECT: float = 1.3
## Shot quality (worse of timing and positioning) for the ratings shown above the player: a
## perfect rating takes perfect timing and the ball met in the racket's sweet spot.
const RATING_PERFECT: float = 1.0
const RATING_GREAT: float = 0.7
const RATING_GOOD: float = 0.4
const RATING_COLOR_PERFECT := Palette.AMBER
const RATING_COLOR_GREAT := Palette.TEAL_LIGHT
const RATING_COLOR_GOOD := Palette.CREAM
const RATING_COLOR_BAD := Palette.RED_LIGHT
## Landing area radius (m) of a rally shot from the worst timing to just outside the perfect
## window, and with perfect timing.
const RALLY_ERROR_RADIUS: Vector2 = Vector2(2.5, 0.9)
const RALLY_ERROR_RADIUS_PERFECT: float = 0.25
## Still holding the stroke button at contact: a weak ball through the middle, landing short
## (m from the net) within this radius (m). Its speed follows from a flight time (s, without air
## drag) drawn per shot, about that of a rally ball, so it comes at ~70-90 km/h without looping
## up: some come a little flatter, some a little higher.
const LATE_SHOT_DEPTH: float = 6.0
const LATE_SHOT_ERROR_RADIUS: float = 1.0
const LATE_SHOT_FLIGHT_TIME: Vector2 = Vector2(0.75, 0.95)

## Rally speed (m/s) from the weakest to the best stroke; ATP averages are ~115 km/h (32 m/s)
## on the forehand and ~105 km/h (29 m/s) on the backhand.
const FOREHAND_SPEED: Vector2 = Vector2(28.0, 33.0)
const BACKHAND_SPEED: Vector2 = Vector2(26.5, 31.0)
const SLICE_SPEED: Vector2 = Vector2(20.0, 24.0)
const DROP_SHOT_SPEED: Vector2 = Vector2(9.0, 13.0)
## Attack pace (m/s) from the weakest to the best stroke: a perfect forehand of the best
## player reaches 47 m/s (~170 km/h). Touch shots have none.
const FOREHAND_ATTACK: Vector2 = Vector2(10.0, 14.0)
const BACKHAND_ATTACK: Vector2 = Vector2(8.0, 12.0)
const SLICE_ATTACK: float = 4.0

## Pressing at most this many seconds before contact is a perfectly timed serve
## (for a player with average timing; the timing stat scales it).
const SERVE_PERFECT_WINDOW: float = 0.08
## Pressing this many seconds or more before contact (or not at all) is the worst timing.
const SERVE_EARLIEST_TIMING: float = 0.5
## Share of the serve speed from an untimed serve to just outside the perfect window; a
## perfectly timed serve gets the full speed.
const SERVE_TIMING_SPEED: Vector2 = Vector2(0.72, 0.9)
## Landing area radius (m) of a serve from untimed to just outside the perfect window, and
## perfectly timed.
const SERVE_ERROR_RADIUS: Vector2 = Vector2(1.6, 0.6)
const SERVE_ERROR_RADIUS_PERFECT: float = 0.2
## Share of the perfectly timed flat serve speed (GameConstants.SERVE_SPEED) per serve type:
## flat 103-121 mph, slice 90-106 mph, kick 79-92 mph.
const SERVE_SPEED_SHARE: Dictionary[ServeType, float] = {
	ServeType.FLAT: 1.0,
	ServeType.SLICE: 0.875,
	ServeType.KICK: 0.76,
}
## Spin per serve type for a right-handed player (x: sidespin, y: topspin).
const SERVE_SPIN: Dictionary[ServeType, Vector3] = {
	ServeType.FLAT: Vector3(0.0, 0.2, 0.0),
	ServeType.SLICE: Vector3(0.75, 0.15, 0.0),
	ServeType.KICK: Vector3(-0.3, 1.0, 0.0),
}
## Speed factor of a second serve.
const SECOND_SERVE_SPEED_FACTOR: float = 0.9

## Camera this player is seen through when it is not the viewport's current camera
## (split screen).
var view_camera: Camera3D
var _device: InputDevice
var _mode: Mode = Mode.FREE

## Stroke button that started the current shot.
var _stroke_action: InputDevice.Action = InputDevice.Action.STRIKE
## Whether the stroke button is still held since the shot started.
var _charging: bool = false
var _charge_time: float = 0.0

## Aim within the current target area: x = left/right, y = short/deep, each in [-1, 1].
var _aim: Vector2 = Vector2.ZERO
## Where the aim is moving to, set by the direction.
var _aim_goal: Vector2 = Vector2.ZERO
## Peak deflection per axis of the current push of the direction.
var _aim_peak: Vector2 = Vector2.ZERO
## World position of the aim, derived from _aim.
var _aiming_at: Vector3 = Vector3.ZERO
## Sign of the server's x position, i.e. which half of the baseline it serves from.
var _serve_side: float = 1.0

## Stroke handed to the player (queued by the controller, executed by the player).
var _pending_stroke: Stroke = null
## Stroke speed, attack pace and spin of the current shot or serve before timing.
var _base_stroke_power: float = 0.0
var _base_attack_power: float = 0.0
var _base_stroke_spin: Vector3 = Vector3.ZERO
## Precision in [0, 1] of the current rally shot (shot control, return and volley skill).
var _shot_precision: float = 0.5

## Random direction inside the unit circle, drawn once per shot or serve.
var _error_direction: Vector2 = Vector2.ZERO
## Flight time (s) of the current shot if it ends up late, drawn once per shot.
var _late_flight_time: float = 0.0
## Timing quality in [0, 1] once the stroke button was released (shot) or pressed (serve).
var _timing_quality: float = 0.0
var _timed: bool = false

var _serve_type: ServeType = ServeType.FLAT
## Serve button held while aiming the serve.
var _serve_action: InputDevice.Action = InputDevice.Action.STRIKE

## Whether the current shot meets the ball out of the air (it then aims like a volley).
var _is_volley_shot: bool = false
## Where the opponent's ball can be met with a groundstroke; null until the opponent hits it,
## or if it does not bounce on this side.
var _contact_window: ContactWindow = null
## Ideal position to meet the opponent's ball; null until the opponent hits it, or if it cannot
## be met.
var _ideal_position: Variant = null
## Positions of the earliest and the latest groundstroke contact; empty for a volley.
var _ideal_range: PackedVector3Array = PackedVector3Array()
## Whether the ideal position was placed for the ball coming in (it then stays).
var _ideal_placed: bool = false


func _ready() -> void:
	var device_id: int = GlobalGameData.get_match_input_device(player.team_index)
	assert(
		device_id != InputDevice.NO_DEVICE_ID,
		"HumanController: no input device assigned to team %d" % player.team_index
	)
	_device = InputDevice.create(device_id)
	player.ball_hit.connect(_on_player_ball_hit)


## Update controller state - called by Player each frame
func update(delta: float) -> void:
	_device.poll()
	_update_ideal_position()

	match _mode:
		Mode.FREE:
			var action: int = _just_pressed_action()
			if action >= 0:
				_begin_shot(action)
		Mode.SHOT:
			_update_shot(delta)
		Mode.SERVE_READY:
			var action: int = _just_pressed_action()
			if action >= 0:
				_begin_serve_aim(action)
		Mode.SERVE_AIM:
			_update_serve_aim(delta)
		Mode.SERVE_SWING:
			_update_serve_swing(delta)


func request_serve() -> void:
	_enter_free_mode()
	_clear_ideal_position()
	_mode = Mode.SERVE_READY
	_serve_side = signf(player.global_position.x)
	_reset_aim()
	_aiming_at = _serve_aim_target()


## The ideal position belongs to the ball it was placed for.
func ball_changed(_ball: Ball) -> void:
	_clear_ideal_position()


func on_lifecycle_phase_changed(current_phase: MatchLifecycleBus.Phase) -> void:
	match current_phase:
		MatchLifecycleBus.Phase.RALLY:
			if _mode == Mode.SERVE_SWING:
				_enter_free_mode()
		MatchLifecycleBus.Phase.POINT_ENDED, MatchLifecycleBus.Phase.IDLE:
			_enter_free_mode()
			_reset_aim()
			_clear_ideal_position()


func get_move_direction() -> Vector3:
	match _mode:
		Mode.FREE:
			return _to_world(_get_direction())
		Mode.SHOT:
			return player.compute_move_dir(SHOT_ADJUST_SPEED)
		Mode.SERVE_READY:
			return _serve_slide_direction()
	return Vector3.ZERO


func get_stroke() -> Stroke:
	return _pending_stroke


func get_aim_marker_position() -> Variant:
	return null if _mode == Mode.FREE else _aiming_at


## Where the player should stand to meet the opponent's next ball, until the ball got past.
func get_ideal_position() -> Variant:
	return null if _has_ball_passed() else _ideal_position


func get_ideal_range() -> PackedVector3Array:
	return PackedVector3Array() if _has_ball_passed() else _ideal_range


func get_aim_marker_radius() -> float:
	match _mode:
		Mode.SHOT:
			return _rally_error_radius(_displayed_shot_quality())
		Mode.SERVE_READY, Mode.SERVE_AIM:
			# Before the toss the marker shows the best the serve can get.
			return _serve_error_radius(1.0)
		Mode.SERVE_SWING:
			return _serve_error_radius(_displayed_serve_quality())
	return BallAimMarker.DEFAULT_RADIUS


func is_aim_marker_highlighted() -> bool:
	match _mode:
		Mode.SHOT:
			return _displayed_shot_quality() >= 1.0
		Mode.SERVE_SWING:
			return _displayed_serve_quality() >= 1.0
	return false


## Returns the stroke button pressed this frame, or -1.
func _just_pressed_action() -> int:
	for action in InputDevice.Action.values():
		if _device.is_action_just_pressed(action):
			return action
	return -1


func _draw_error_direction() -> void:
	_error_direction = Vector2.from_angle(randf() * TAU) * sqrt(randf())


## Rally
##########


func _begin_shot(action: InputDevice.Action) -> void:
	_mode = Mode.SHOT
	_stroke_action = action
	_charging = true
	_charge_time = 0.0
	_timed = false
	_is_volley_shot = false
	_draw_error_direction()
	_late_flight_time = randf_range(LATE_SHOT_FLIGHT_TIME.x, LATE_SHOT_FLIGHT_TIME.y)
	_aiming_at = _rally_aim_target()


func _update_charge(delta: float) -> void:
	if not _charging:
		return
	if not _device.is_action_held(_stroke_action):
		_charging = false
		return
	_charge_time += delta


## Share in [0, 1] of the attack pace charged by holding the stroke button.
func _charge01() -> float:
	return clampf(_charge_time / FULL_CHARGE_TIME, 0.0, 1.0)


func _update_shot(delta: float) -> void:
	var was_charging: bool = _charging
	_update_charge(delta)
	if was_charging and not _charging:
		_timed = true
		_timing_quality = _shot_timing_quality(player.get_seconds_to_contact())
	_update_aim(delta)
	_aiming_at = _rally_aim_target()

	# During the swing the stroke still follows aim and timing until the racket meets the ball.
	if player.get_current_state() == PlayerStateMachine.State.STROKING:
		if player.queued_stroke:
			_apply_shot_timing(player.queued_stroke)
		return

	if not _is_ball_incoming():
		# Released before the ball came, or the ball got past the player (the shot is missed
		# even while the button is still held).
		if not _charging or _has_ball_passed():
			_enter_free_mode()
		return
	var step: TrajectoryStep = _shot_contact_step()
	if not step:
		return

	_pending_stroke = _build_rally_stroke(step)
	move_to_contact(step, _pending_stroke)


## Places the contact window and the ideal position once, as soon as the opponent's ball comes
## in.
func _update_ideal_position() -> void:
	if _ideal_placed or not _is_ball_incoming():
		return
	var trajectory: Array[TrajectoryStep] = player.ball.predict_trajectory()
	_contact_window = contact_window(trajectory)
	var step: TrajectoryStep = get_ideal_contact_step(trajectory, _contact_window)
	_ideal_position = ideal_position_for_step(step) if step else null
	_ideal_range = PackedVector3Array()
	if step and not step.is_volley_contact():
		var candidates: Array[TrajectoryStep] = _contact_window.steps_in(trajectory)
		_ideal_range.append(ideal_position_for_step(candidates.front()))
		_ideal_range.append(ideal_position_for_step(candidates.back()))
	_ideal_placed = true


func _clear_ideal_position() -> void:
	_contact_window = null
	_ideal_position = null
	_ideal_range = PackedVector3Array()
	_ideal_placed = false


## Where the shot meets the ball: in the net zone the player steps in and volleys it before the
## bounce; otherwise at the point of the contact window closest to where the player stands. A
## ball that does not bounce on this side, or is past the window, is met where it passes the
## player.
func _shot_contact_step() -> TrajectoryStep:
	var trajectory: Array[TrajectoryStep] = player.ball.predict_trajectory()
	var step: TrajectoryStep = _closest_playable_step(trajectory)
	if step and step.is_in_net_zone() and step.is_volley_contact():
		var intercept: TrajectoryStep = _volley_intercept_step(trajectory, SHOT_ADJUST_SPEED)
		return intercept if intercept else step
	if not _contact_window:
		return step
	var closest_contact: TrajectoryStep = null
	var closest_distance: float = INF
	for candidate in _contact_window.steps_in(trajectory):
		var distance: float = absf(ideal_position_for_step(candidate).z - player.global_position.z)
		if distance < closest_distance:
			closest_contact = candidate
			closest_distance = distance
	return closest_contact if closest_contact else step


## Timing quality in [0, 1] of releasing the stroke button `seconds_to_contact` before contact.
## Taking the ball earlier narrows the perfect window, taking it later widens it.
func _shot_timing_quality(seconds_to_contact: float) -> float:
	var window: float = PERFECT_TIMING_WINDOW
	if _pending_stroke:
		window *= lerpf(
			1.0, EARLY_CONTACT_TIMING_WINDOW, ContactWindow.early_share(_pending_stroke.earliness)
		)
		window *= lerpf(
			1.0, LATE_CONTACT_TIMING_WINDOW, ContactWindow.late_share(_pending_stroke.earliness)
		)
	return _timing_quality_for(seconds_to_contact, window, EARLIEST_TIMING)


## Timing quality the shot gets at contact: the release timing, or the worst while held.
func _effective_shot_quality() -> float:
	return _timing_quality if _timed else 0.0


## Timing quality shown by the aim marker: the release timing, or while the button is held
## the timing a release right now would give.
func _displayed_shot_quality() -> float:
	if _timed:
		return _timing_quality
	return _shot_timing_quality(player.get_seconds_to_contact())


func _rally_error_radius(quality: float) -> float:
	var radius: float = _by_timing(quality, RALLY_ERROR_RADIUS, RALLY_ERROR_RADIUS_PERFECT)
	return radius * lerpf(1.25, 0.75, _shot_precision)


## Points a rally stroke at the current aim with its landing error, speed and attack pace by
## timing. Still holding the button at contact plays a weak ball short through the middle.
func _apply_shot_timing(stroke: Stroke) -> void:
	var quality: float = _effective_shot_quality()
	stroke.stroke_spin = _base_stroke_spin * _by_timing(quality, TIMING_SPIN, TIMING_SPIN_PERFECT)
	if not _timed:
		var late_target: Vector3 = _opponent_court_point(0.0, LATE_SHOT_DEPTH)
		var late_error: Vector2 = _error_direction * LATE_SHOT_ERROR_RADIUS
		stroke.intended_stroke_target = late_target
		stroke.stroke_target = late_target + Vector3(late_error.x, 0.0, late_error.y)
		var distance: float = absf(stroke.stroke_target.z - stroke.step.point.z)
		stroke.stroke_power = minf(_base_stroke_power, distance / _late_flight_time)
		stroke.attack_power = 0.0
		return

	var error: Vector2 = _error_direction * _rally_error_radius(quality)
	stroke.intended_stroke_target = _aiming_at
	stroke.stroke_target = _aiming_at + Vector3(error.x, 0.0, error.y)
	stroke.stroke_power = _base_stroke_power * _by_timing(quality, TIMING_SPEED, 1.0)
	stroke.attack_power = _base_attack_power * _by_timing(quality, TIMING_ATTACK, 1.0)


## Builds the rally stroke for the given contact step, forehand or backhand by ball side.
## A ball taken before the bounce is volleyed (a drop shot becomes a drop volley).
func _build_rally_stroke(step: TrajectoryStep) -> Stroke:
	var to_ball: Vector3 = step.point - player.global_position
	var is_forehand: bool = to_ball.dot(player.global_basis.x) > 0.0
	var is_volley: bool = step.is_volley_contact()
	_is_volley_shot = is_volley
	var stamina: float = player.get_stamina_ratio()

	var stroke: Stroke = Stroke.new()
	stroke.step = step
	if is_volley:
		_set_volley(stroke, is_forehand)
	else:
		_set_groundstroke(stroke, is_forehand, stamina)
		if _contact_window:
			stroke.earliness = _contact_window.earliness_of(step)

	# Spin skill sets how much of the stroke's spin the player gets on the ball.
	var spin_skill: float = player.stats.spin_control01(stroke.stroke_type, stamina)
	stroke.stroke_spin.y *= lerpf(0.6, 1.1, spin_skill)

	_shot_precision = player.stats.rally_precision01(
		stamina, player.is_returning_serve(), is_volley
	)
	# A volley has no backswing to charge.
	if not is_volley:
		stroke.attack_power *= _charge01()
	stroke.intended_stroke_power = stroke.stroke_power
	_base_stroke_power = stroke.stroke_power
	_base_attack_power = stroke.attack_power
	_base_stroke_spin = stroke.stroke_spin
	_apply_shot_timing(stroke)
	return stroke


## Volley or drop volley: a short punch with backspin; volley skill sets its own pace, the
## incoming pace and contact height do the rest (see Player).
func _set_volley(stroke: Stroke, is_forehand: bool) -> void:
	var volley_skill: float = player.stats.volley01()
	if _stroke_action == InputDevice.Action.DROP_SHOT:
		stroke.stroke_type = (
			Stroke.StrokeType.FOREHAND_DROP_VOLLEY
			if is_forehand
			else Stroke.StrokeType.BACKHAND_DROP_VOLLEY
		)
		stroke.stroke_power = lerpf(
			GameConstants.DROP_VOLLEY_SPEED.x, GameConstants.DROP_VOLLEY_SPEED.y, volley_skill
		)
		stroke.stroke_spin = GameConstants.DROP_VOLLEY_SPIN
		return

	stroke.stroke_type = (
		Stroke.StrokeType.FOREHAND_VOLLEY if is_forehand else Stroke.StrokeType.BACKHAND_VOLLEY
	)
	stroke.stroke_power = lerpf(
		GameConstants.VOLLEY_PUNCH_SPEED.x, GameConstants.VOLLEY_PUNCH_SPEED.y, volley_skill
	)
	stroke.attack_power = GameConstants.VOLLEY_PUT_AWAY_PACE
	stroke.stroke_spin = GameConstants.VOLLEY_SPIN


func _set_groundstroke(stroke: Stroke, is_forehand: bool, stamina: float) -> void:
	if _stroke_action == InputDevice.Action.DROP_SHOT:
		stroke.stroke_type = (
			Stroke.StrokeType.FOREHAND_DROP_SHOT
			if is_forehand
			else Stroke.StrokeType.BACKHAND_DROP_SHOT
		)
		var touch_skill: float = player.stats.spin_control01(stroke.stroke_type, stamina)
		stroke.stroke_power = lerpf(DROP_SHOT_SPEED.x, DROP_SHOT_SPEED.y, touch_skill)
		stroke.stroke_spin = GameConstants.DROP_SHOT_SPIN
		return

	if is_forehand:
		stroke.stroke_type = Stroke.StrokeType.FOREHAND
		var fh_skill: float = player.stats.shot_side_skill01(false)
		stroke.stroke_power = lerpf(FOREHAND_SPEED.x, FOREHAND_SPEED.y, fh_skill)
		stroke.attack_power = lerpf(FOREHAND_ATTACK.x, FOREHAND_ATTACK.y, fh_skill)
		stroke.stroke_spin = GameConstants.FOREHAND_SPIN
		return

	var bh_skill: float = player.stats.shot_side_skill01(true)
	if _stroke_action == InputDevice.Action.SLICE:
		stroke.stroke_type = Stroke.StrokeType.BACKHAND_SLICE
		stroke.stroke_power = lerpf(SLICE_SPEED.x, SLICE_SPEED.y, bh_skill)
		stroke.attack_power = SLICE_ATTACK
		stroke.stroke_spin = GameConstants.BACKHAND_SLICE_SPIN
		return

	stroke.stroke_type = Stroke.StrokeType.BACKHAND
	stroke.stroke_power = lerpf(BACKHAND_SPEED.x, BACKHAND_SPEED.y, bh_skill)
	stroke.attack_power = lerpf(BACKHAND_ATTACK.x, BACKHAND_ATTACK.y, bh_skill)
	stroke.stroke_spin = GameConstants.BACKHAND_SPIN


## Serve
##########


func _begin_serve_aim(action: InputDevice.Action) -> void:
	_mode = Mode.SERVE_AIM
	_serve_action = action
	match action:
		InputDevice.Action.SLICE:
			_serve_type = ServeType.SLICE
		InputDevice.Action.DROP_SHOT:
			_serve_type = ServeType.KICK
		_:
			_serve_type = ServeType.FLAT
	player.cancel_movement()


func _update_serve_aim(delta: float) -> void:
	_update_aim(delta)
	_aiming_at = _serve_aim_target()
	if _device.is_action_held(_serve_action):
		return

	# Releasing the serve button tosses the ball.
	_timed = false
	_draw_error_direction()
	_pending_stroke = _build_serve_stroke()
	_mode = Mode.SERVE_SWING


func _update_serve_swing(delta: float) -> void:
	_update_aim(delta)
	_aiming_at = _serve_aim_target()
	if not _timed and _just_pressed_action() >= 0:
		_timed = true
		_timing_quality = _serve_timing_quality(player.get_seconds_to_contact())
	_apply_serve_timing(_pending_stroke)


## Timing quality in [0, 1] of pressing `seconds_to_contact` before the serve contact.
func _serve_timing_quality(seconds_to_contact: float) -> float:
	return _timing_quality_for(seconds_to_contact, SERVE_PERFECT_WINDOW, SERVE_EARLIEST_TIMING)


func _displayed_serve_quality() -> float:
	if _timed:
		return _timing_quality
	return _serve_timing_quality(player.get_seconds_to_contact())


func _serve_error_radius(quality: float) -> float:
	var precision: float = player.stats.serve_accuracy01(player.get_stamina_ratio())
	var radius: float = _by_timing(quality, SERVE_ERROR_RADIUS, SERVE_ERROR_RADIUS_PERFECT)
	return radius * lerpf(1.25, 0.75, precision)


## Points the serve at the current aim with its landing error and speed by timing.
func _apply_serve_timing(stroke: Stroke) -> void:
	var quality: float = _timing_quality if _timed else 0.0
	var error: Vector2 = _error_direction * _serve_error_radius(quality)
	stroke.intended_stroke_target = _aiming_at
	stroke.stroke_target = _aiming_at + Vector3(error.x, 0.0, error.y)
	stroke.stroke_power = _base_stroke_power * _by_timing(quality, SERVE_TIMING_SPEED, 1.0)
	stroke.stroke_spin = _base_stroke_spin * _by_timing(quality, TIMING_SPIN, TIMING_SPIN_PERFECT)


func _build_serve_stroke() -> Stroke:
	var stroke: Stroke = Stroke.new()
	stroke.stroke_type = Stroke.StrokeType.SERVE

	_base_stroke_power = (
		lerpf(
			GameConstants.SERVE_SPEED.x, GameConstants.SERVE_SPEED.y, player.stats.serve_power01()
		)
		* SERVE_SPEED_SHARE[_serve_type]
	)
	if player.session.is_second_serve():
		_base_stroke_power *= SECOND_SERVE_SPEED_FACTOR
	stroke.intended_stroke_power = _base_stroke_power

	var spin: Vector3 = SERVE_SPIN[_serve_type]
	var stamina: float = player.get_stamina_ratio()
	match _serve_type:
		ServeType.SLICE:
			# Slice skill sets the sidespin of a slice serve.
			var slice_skill: float = player.stats.spin_control01(
				Stroke.StrokeType.BACKHAND_SLICE, stamina
			)
			spin *= lerpf(0.6, 1.1, slice_skill)
		ServeType.KICK:
			# Topspin skill sets the kick of a kick serve.
			var topspin_skill: float = player.stats.spin_control01(
				Stroke.StrokeType.FOREHAND, stamina
			)
			spin *= lerpf(0.6, 1.1, topspin_skill)
	if player.player_data.hand == "L":
		spin.x = -spin.x
	_base_stroke_spin = spin

	_apply_serve_timing(stroke)
	return stroke


## Shared
###########


## Timing quality in [0, 1]: 1 within the perfect window before contact, falling to 0 at
## `earliest` seconds before contact. The player's timing stat scales the perfect window.
func _timing_quality_for(
	seconds_to_contact: float, perfect_window: float, earliest: float
) -> float:
	var timing_skill: float = player.stats.timing01(player.get_stamina_ratio())
	var window: float = perfect_window * lerpf(0.75, 1.35, timing_skill)
	var early_by: float = seconds_to_contact - window
	return 1.0 - clampf(early_by / (earliest - window), 0.0, 1.0)


## Effect of the timing `quality`: `perfect` for perfect timing, otherwise from `below_perfect.x`
## at the worst timing to `below_perfect.y` just outside the perfect window.
static func _by_timing(quality: float, below_perfect: Vector2, perfect: float) -> float:
	if quality >= 1.0:
		return perfect
	return lerpf(below_perfect.x, below_perfect.y, quality)


## Sets the aim goal from the direction, per axis, and moves the aim toward it. Full
## deflection in any direction reaches the edge of the target area (diagonals reach the
## corners). An axis easing back toward neutral keeps its goal.
func _update_aim(delta: float) -> void:
	var direction: Vector2 = _get_direction()
	var largest_axis: float = maxf(absf(direction.x), absf(direction.y))
	if largest_axis == 0.0:
		_aim_peak = Vector2.ZERO
	else:
		var square: Vector2 = direction / largest_axis * direction.length()
		_update_aim_axis(Vector2.AXIS_X, square.x)
		_update_aim_axis(Vector2.AXIS_Y, square.y)
	_aim = _aim.move_toward(_aim_goal, AIM_SPEED * delta)


func _update_aim_axis(axis: int, value: float) -> void:
	var magnitude: float = absf(value)
	if magnitude < AIM_NEUTRAL:
		_aim_peak[axis] = 0.0
		return
	if signf(value) != signf(_aim_goal[axis]):
		# Pushing to the other side starts a new push.
		_aim_peak[axis] = 0.0
	if magnitude >= _aim_peak[axis] * AIM_RELEASE_RATIO:
		_aim_peak[axis] = maxf(_aim_peak[axis], magnitude)
		_aim_goal[axis] = value


func _reset_aim() -> void:
	_aim = Vector2.ZERO
	_aim_goal = Vector2.ZERO
	_aim_peak = Vector2.ZERO


func _enter_free_mode() -> void:
	if _mode != Mode.FREE:
		player.cancel_movement()
	_mode = Mode.FREE
	_pending_stroke = null
	_charging = false
	_charge_time = 0.0


## Whether the ball moves toward this player's baseline and has not passed the player yet.
func _is_ball_incoming() -> bool:
	var ball: Ball = player.ball
	if not is_instance_valid(ball):
		return false
	var own_side: float = signf(player.global_position.z)
	var ball_in_front: bool = (ball.global_position.z - player.global_position.z) * own_side < 0.0
	return ball.velocity.z * own_side > 0.0 and ball_in_front


## Whether the ball is between the player and its own baseline: it got past the player.
func _has_ball_passed() -> bool:
	var ball: Ball = player.ball
	if not is_instance_valid(ball):
		return true
	var own_side: float = signf(player.global_position.z)
	return (ball.global_position.z - player.global_position.z) * own_side > 0.0


## Device direction relative to this player (x = right, y = forward). The device direction is
## relative to the screen, so it is turned by the view camera's facing on the ground.
func _get_direction() -> Vector2:
	var camera: Camera3D = view_camera if view_camera else player.get_viewport().get_camera_3d()
	# The camera's right axis stays horizontal (no camera rolls); "up the screen" is the ground
	# direction perpendicular to it, also for cameras looking straight down.
	var screen_right: Vector3 = Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z)
	screen_right = screen_right.normalized()
	var screen_up: Vector3 = Vector3.UP.cross(screen_right)
	var device_direction: Vector2 = _device.get_direction()
	var world: Vector3 = screen_right * device_direction.x + screen_up * device_direction.y
	return Vector2(world.dot(player.global_basis.x), world.dot(-player.global_basis.z))


## Converts a direction relative to this player (x = right, y = forward) into a world direction.
func _to_world(direction: Vector2) -> Vector3:
	var right: Vector3 = player.global_basis.x
	var forward: Vector3 = -player.global_basis.z
	var world: Vector3 = right * direction.x + forward * direction.y
	world.y = 0.0
	return world


## Slides the server along the baseline, staying between the center mark and the sideline.
## Moves toward a clamped target so the server slows down at the limits instead of overshooting.
func _serve_slide_direction() -> Vector3:
	var slide: float = _get_direction().x
	if is_zero_approx(slide):
		player.cancel_movement()
		return Vector3.ZERO

	var bound_a: float = _serve_side * SERVE_CENTER_MARGIN
	var bound_b: float = _serve_side * GameConstants.COURT_WIDTH_HALF
	var target: Vector3 = (
		player.global_position + _to_world(Vector2(slide, 0.0)) * SERVE_SLIDE_LOOKAHEAD
	)
	target.x = clampf(target.x, minf(bound_a, bound_b), maxf(bound_a, bound_b))
	target.z = player.global_position.z
	player.request_move_to(target)
	return player.compute_move_dir()


## Rally target in the opponent's court: aim x picks the side, aim y the depth.
## A volley aims shorter, and a neutral aim goes toward the open court away from the opponent.
func _rally_aim_target() -> Vector3:
	var depth_min: float = GameConstants.SERVICE_LINE
	var depth_max: float = GameConstants.COURT_LENGTH_HALF - AIM_LINE_MARGIN
	var aim_x: float = _aim.x
	if _stroke_action == InputDevice.Action.DROP_SHOT:
		depth_min = DROP_SHOT_DEPTH_MIN
		depth_max = DROP_SHOT_DEPTH_MAX
	elif _is_volley_shot:
		depth_min = _volley_depth_min()
		depth_max = GameConstants.VOLLEY_DEPTH_MAX
		aim_x = _toward_open_court(aim_x)

	var lateral: float = aim_x * (GameConstants.COURT_WIDTH_HALF - AIM_LINE_MARGIN)
	var depth: float = lerpf(depth_min, depth_max, (_aim.y + 1.0) * 0.5)
	return _opponent_court_point(lateral, depth)


## Shortest volley target: a high ball can be angled off short, a low one only goes deep.
func _volley_depth_min() -> float:
	var put_away: float = 0.0
	if _pending_stroke and _pending_stroke.step:
		put_away = Player.volley_put_away_share(_pending_stroke.step.point.y)
	return lerpf(GameConstants.VOLLEY_DEPTH_LOW_BALL, GameConstants.VOLLEY_DEPTH_MIN, put_away)


## Remaps an aim axis in [-1, 1] so that neutral points to the open court side (away from the
## opponent) while full deflection still reaches both sidelines.
func _toward_open_court(aim_x: float) -> float:
	var right_x: float = signf(player.global_basis.x.x)
	var open_side: float = -signf(player.session.get_opponent_position(player).x) * right_x
	var neutral: float = open_side * GameConstants.VOLLEY_OPEN_COURT_AIM
	if aim_x < 0.0:
		return lerpf(neutral, -1.0, -aim_x)
	return lerpf(neutral, 1.0, aim_x)


## Serve target in the diagonal service box: aim x picks the side, aim y the depth.
func _serve_aim_target() -> Vector3:
	var right_x: float = signf(player.global_basis.x.x)
	var box_sign: float = -_serve_side * right_x
	var inner: float = box_sign * AIM_LINE_MARGIN
	var outer: float = box_sign * (GameConstants.COURT_WIDTH_HALF - AIM_LINE_MARGIN)
	var lateral: float = lerpf(minf(inner, outer), maxf(inner, outer), (_aim.x + 1.0) * 0.5)
	var depth: float = lerpf(
		GameConstants.SERVICE_LINE * 0.5,
		GameConstants.SERVICE_LINE - AIM_LINE_MARGIN,
		(_aim.y + 1.0) * 0.5
	)
	return _opponent_court_point(lateral, depth)


## World point on the opponent's half: `lateral` along this player's right, `depth` from the net.
func _opponent_court_point(lateral: float, depth: float) -> Vector3:
	var right_x: float = signf(player.global_basis.x.x)
	var opponent_side: float = -signf(player.global_position.z)
	return Vector3(lateral * right_x, 0.0, depth * opponent_side)


func _on_player_ball_hit() -> void:
	_show_shot_rating()
	_clear_ideal_position()
	if _mode == Mode.SHOT:
		_enter_free_mode()
	_reset_aim()
	_device.vibrate(0.64, 0.4, 0.1)


## Shows how good the shot was: the worse of timing and positioning decides the rating, and a
## poor rating names what went wrong. A well-hit shot lifts the player's confidence a little.
func _show_shot_rating() -> void:
	var timing: float = _timing_quality if _timed else 0.0
	var positioning: float = player.last_positioning_quality
	var quality: float = minf(timing, positioning)
	player.mental_state.on_stroke(quality)
	if quality >= RATING_PERFECT:
		player.show_shot_feedback("PERFECT!", RATING_COLOR_PERFECT)
	elif quality >= RATING_GREAT:
		player.show_shot_feedback("GREAT", RATING_COLOR_GREAT)
	elif quality >= RATING_GOOD:
		player.show_shot_feedback("GOOD", RATING_COLOR_GOOD)
	elif positioning < timing:
		player.show_shot_feedback("OUT OF POSITION", RATING_COLOR_BAD)
	elif not _timed:
		var miss_text: String = "MISTIMED" if _mode == Mode.SERVE_SWING else "LATE"
		player.show_shot_feedback(miss_text, RATING_COLOR_BAD)
	else:
		player.show_shot_feedback("EARLY", RATING_COLOR_BAD)
