extends Node

## Per player: current stroke blend object, its start clock, restarts and clip changes since the last hit
var _state: Array[Dictionary] = [{}, {}]
var _rows: Array[String] = []
var _players: Array[Player] = []


func _ready() -> void:
	Engine.time_scale = 3.0
	var players: Array = GlobalGameData.get_ranked_players()
	GlobalGameData.set_match_players(players[0], players[1])
	GlobalGameData.set_match_input_devices(InputDevice.NO_DEVICE_ID, InputDevice.NO_DEVICE_ID)
	var m: Node = load("res://scenes/match/tennis_match.tscn").instantiate()
	add_child(m)
	_players = [m.player0, m.player1]
	for i in 2:
		_state[i] = {"stroke": null, "start": 0.0, "restarts": 0, "kinds": []}
		_players[i].ball_hit.connect(_on_hit.bind(i))
	var t := 0.0
	while t < float(OS.get_cmdline_user_args()[0]):
		await get_tree().process_frame
		t += get_process_delta_time()
	for r in _rows:
		print(r)
	SavedMatch.delete_saved(false)
	get_tree().quit()


func _process(_delta: float) -> void:
	for i in _players.size():
		var anim: PlayerAnimator = _players[i].model.animator
		var s: StrokeBlend = anim.get_stroke()
		var st: Dictionary = _state[i]
		if s != st.stroke and s != null:
			if st.stroke != null and not _players[i].model.animator.get_stroke() == null:
				st.restarts += 1
			st.stroke = s
			st.start = anim.get_stroke_time()
			st.kinds.append("%s/%s" % [s.low.animation, s.high.animation])


func _on_hit(i: int) -> void:
	var p: Player = _players[i]
	var anim: PlayerAnimator = p.model.animator
	var st: Dictionary = _state[i]
	var s: StrokeBlend = anim.get_stroke()
	if s == null or p.queued_stroke == null:
		return
	var hit: float = anim.get_marker_time(s, PlayerAnimator.HIT_MARKER)
	var swing: float = anim.get_marker_time(s, PlayerAnimator.SWING_MARKER) if anim.has_marker(s, PlayerAnimator.SWING_MARKER) else 0.0
	var played: float = (hit - st.start) / hit
	_rows.append("HIT type=%s clips=%s start=%.2f swing_marker=%.2f hit=%.2f played=%.0f%% swings_started=%d kinds=%s" % [
		Stroke.StrokeType.keys()[p.queued_stroke.stroke_type], s.low.animation + "/" + s.high.animation,
		st.start, swing, hit, played * 100.0, st.kinds.size(), ",".join(st.kinds)])
	st.kinds = []
	st.stroke = null
