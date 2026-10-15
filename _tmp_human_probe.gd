extends Node

var _hc: HumanController
var _p: Player
var _rows: Array[String] = []
var _press_at: float = -1.0
var _incoming_t: float = 0.0
var _button: MouseButton = MOUSE_BUTTON_LEFT
var _held: bool = false
var _toggle: bool = false
## Per incoming ball: swings started (play_stroke from scratch), families seen, earliest take-back share skipped
var _starts := 0
var _families: Array[String] = []
var _skipped := 0.0
var _last_stroke: StrokeBlend = null
var _was_incoming := false
var _held_once := false
var _hit_this_ball := false
var _min_dist := INF


func _ready() -> void:
	seed(int(OS.get_cmdline_user_args()[1]))
	Engine.time_scale = 3.0
	var players: Array = GlobalGameData.get_ranked_players()
	GlobalGameData.set_match_players(players[0], players[1])
	GlobalGameData.set_match_input_devices(InputDevice.NO_DEVICE_ID, KeyboardInput.DEVICE_ID)
	var m: Node = load("res://scenes/match/tennis_match.tscn").instantiate()
	add_child(m)
	_p = m.player1
	_hc = _p.controller
	_p.ball_hit.connect(_on_hit)
	var t := 0.0
	while t < float(OS.get_cmdline_user_args()[0]):
		await get_tree().process_frame
		t += get_process_delta_time()
	print("ENDED t=", t)
	for r in _rows:
		print(r)
	SavedMatch.delete_saved(false)
	get_tree().quit()


func _mouse(button: MouseButton, pressed: bool) -> void:
	if KeyboardInput.get_layout() == KeyboardInput.Layout.KEYBOARD_ONLY:
		var k := InputEventKey.new()
		k.physical_keycode = KEY_K if button == MOUSE_BUTTON_RIGHT else KEY_J
		k.keycode = k.physical_keycode
		k.pressed = pressed
		Input.parse_input_event(k)
		return
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.button_mask = (1 << (button - 1)) if pressed else 0
	Input.parse_input_event(e)


var _dbg := 0.0


func _physics_process(delta: float) -> void:
	if not _hc:
		return
	_dbg += delta
	if false:
		_dbg = 0.0
		print("input_left=", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), " input_right=", Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), " dev_strike=", _hc._device.is_action_held(InputDevice.Action.STRIKE), " dev_slice=", _hc._device.is_action_held(InputDevice.Action.SLICE), " layout=", KeyboardInput.get_layout(), " btn=", _button, " mode=", HumanController.Mode.keys()[_hc._mode], " incoming=", _hc._is_ball_incoming(), " ball=", _p.ball != null, " held=", _held, " phase=", _p.get_lifecycle_bus().get_phase(), " score=", (_p.session as MatchManager).match_data.score.points, " state=", (_p.session as MatchManager).current_state)
	var anim: PlayerAnimator = _p.model.animator
	var sw: StrokeBlend = _p._swing_timer.swing
	if sw != null and sw != _last_stroke and sw.low.animation != &"serve":
		if _last_stroke == null:
			_starts += 1
			var marker: float = anim.get_marker_time(sw, PlayerAnimator.SWING_MARKER)
			_skipped = clampf(anim.get_stroke_time() / marker, 0.0, 1.0) if marker > 0.0 else 0.0
			if _p._swing_timer.is_released():
				_skipped = 1.0
			_families.append("start:" + String(sw.low.animation))
		elif sw.is_same_stroke(_last_stroke):
			_families.append("swap:" + String(sw.low.animation))
		else:
			_families.append("?:" + String(sw.low.animation))
	if sw == null and _last_stroke != null and not _families.is_empty():
		_families.append("drop")
	_last_stroke = sw
	# serve when asked
	if _hc._mode == HumanController.Mode.SERVE_READY and not _held:
		_mouse(MOUSE_BUTTON_LEFT, true)
		_held = true
		_button = MOUSE_BUTTON_LEFT
		return
	if _hc._mode == HumanController.Mode.SERVE_AIM and _held:
		_mouse(MOUSE_BUTTON_LEFT, false)
		_held = false
		return
	if _hc._mode == HumanController.Mode.SERVE_SWING:
		if not _hc._timed and _p.get_seconds_to_contact() < 0.06 and not _held:
			_mouse(MOUSE_BUTTON_LEFT, true)
			_held = true
		elif _held and _hc._timed:
			_mouse(MOUSE_BUTTON_LEFT, false)
			_held = false
		return
	# rally
	var incoming: bool = _hc._is_ball_incoming()
	if incoming and _p.queued_stroke and _p._swing_timer.swing:
		var cp: Vector3 = _p.model.get_contact_point(_p._swing_timer.swing)
		_min_dist = minf(_min_dist, _p.ball.global_position.distance_to(cp))
	if _was_incoming and not incoming and _p.ball != null and (_p.session as MatchManager).current_state == MatchManager.MatchState.PLAY:
		if not _hit_this_ball and _held_once:
			_rows.append("MISS closest_to_swing_contact=%.2f clips=%s" % [_min_dist, ",".join(_families)])
			_reset()
	if not _was_incoming and incoming:
		_hit_this_ball = false
		_held_once = false
		_min_dist = INF
	_was_incoming = incoming
	if _held:
		_held_once = true
	if incoming:
		_incoming_t += delta
		if _press_at < 0.0:
			_press_at = randf_range(0.2, 0.9)
			_toggle = not _toggle
			_button = MOUSE_BUTTON_RIGHT if _toggle else MOUSE_BUTTON_LEFT
		if not _held and _incoming_t >= _press_at and _hc._mode == HumanController.Mode.FREE:
			_mouse(_button, true)
			_held = true
		elif _held and _p.get_seconds_to_contact() < 0.1:
			_mouse(_button, false)
			_held = false
	else:
		if _held:
			_mouse(_button, false)
			_held = false
		_incoming_t = 0.0
		_press_at = -1.0


func _on_hit() -> void:
	_hit_this_ball = true
	var q: Stroke = _p.queued_stroke
	if q == null or q.stroke_type == Stroke.StrokeType.SERVE:
		_reset()
		return
	print("hit at ", Time.get_ticks_msec())
	_rows.append("HIT %s pressed_after=%.2f swings_started=%d takeback_skipped=%.0f%% clips=%s" % [
		Stroke.StrokeType.keys()[q.stroke_type], _press_at, _starts, _skipped * 100.0, ",".join(_families)])
	_reset()


func _reset() -> void:
	_starts = 0
	_families = []
	_skipped = 0.0
