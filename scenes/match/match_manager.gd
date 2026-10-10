## Manages match state, scoring, and game flow for tennis matches
class_name MatchManager
extends PlaySession

## Emitted whenever the match active ball reference changes
signal active_ball_changed(ball: Ball)
## Emitted when a player has won the match
signal match_finished(winner_index: int)
## Emitted when a set has ended and the match pauses until continue_after_set_break()
signal set_break_started(set_number: int)
## Emitted when play resumes after a set break
signal set_break_ended

enum MatchState { NOT_STARTED, IDLE, SERVE, SECOND_SERVE, PLAY, FAULT, GAME_OVER }

## Rally length (shots, serve included) that excites the crowd the most
const MOST_EXCITING_RALLY_SHOTS: int = 12
## Seconds the ball flies on after a first serve fault or a let before the serve is taken again
const SERVE_AGAIN_BREAK: float = 2.0

@export var player0: Player
@export var player1: Player
@export var court: Court
@export var stadium: Stadium
@export var television_hud: TelevisionHud
@export var umpire: Umpire
@export var crowd: Crowd
@export var cameras: MatchCameras

## Ball in play, null between points
var ball: Ball
## Reference to the last player who hit the ball
var last_hitter: Player
var match_data: MatchData

var current_state: MatchState = MatchState.NOT_STARTED:
	set(value):
		if value != current_state:
			current_state = value
			DebugLogger.log(self, "State changed to: %s" % MatchState.keys()[value])

## Half of the court the serve must land in
var valid_serve_zone: Court.CourtRegion
## Half of the court the next bounce must land in
var valid_rally_zone: Court.CourtRegion
## Number of ground contacts since the last stroke
var ground_contacts: int = 0

## Ball of a finished point; stays on court until the next serve
var _finished_ball: Ball
## Whether the current serve clipped the net cord (a let if it lands in the service box)
var _serve_clipped_net: bool = false
## Serve (1 or 2) that started the current rally, 0 while no serve was in
var _point_serve_number: int = 0
## Whether the current point is a break point
var _point_is_break_point: bool = false
## Whether each player volleyed during the current point
var _point_volleyed: Array[bool] = [false, false]


func _ready() -> void:
	set_meta("logger_name", "MatchManager")
	match_data = MatchData.new()

	var players: Array[Player] = [player0, player1]
	for i in players.size():
		var player: Player = players[i]
		player.opponent = players[1 - i]
		player.session = self
		player.ball_hit.connect(_on_player_ball_hit.bind(i))
		player.ball_spawned.connect(set_active_ball)
		active_ball_changed.connect(player.set_active_ball)
		var bus: MatchLifecycleBus = player.get_lifecycle_bus()
		bus.serve_requested.connect(_on_player_serve_requested)
		bus.serve_completed.connect(_on_player_serve_completed)
		bus.point_ended.connect(stadium.stop_serve_clocks.unbind(1))
		television_hud.set_player(i, player.player_data)
		cameras.register_camera(player.first_person_camera)
	television_hud.update_score(match_data.score)
	stadium.show_bench_rackets(players)
	_update_players_for_next_point()

	await place_players()
	cameras.open_match()
	_start_point()


## Handle debug input (T key to add point for testing)
func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_pressed() and event.keycode == KEY_T:
		add_point(randi() % 2)


func _physics_process(delta: float) -> void:
	if current_state == MatchState.NOT_STARTED or current_state == MatchState.GAME_OVER:
		return
	for i in 2:
		var player: Player = get_player(i)
		var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
		match_data.statistics[i].distance_covered += horizontal.length() * delta


## Set active ball and connect its signals
func set_active_ball(b: Ball) -> void:
	if is_instance_valid(ball) and ball != b:
		_remove_balls()

	ball = b
	active_ball_changed.emit(ball)
	if ball:
		ball.on_ground.connect(_on_ball_on_ground)
		ball.on_net_cord.connect(_on_ball_on_net_cord)


func get_player(index: int) -> Player:
	return player0 if index == 0 else player1


func get_player_index(player: Player) -> int:
	return 0 if player == player0 else 1


func get_server() -> Player:
	return get_player(match_data.get_server())


func is_return_of_serve(_player: Player) -> bool:
	return match_data.rally_length == 1


func is_second_serve() -> bool:
	return current_state == MatchState.SECOND_SERVE


func get_opponent_position(player: Player) -> Vector3:
	return player.opponent.global_position


## Resumes the match after a set break.
func continue_after_set_break() -> void:
	set_break_ended.emit()


## Add a point to the winner and handle score update
func add_point(winner: int) -> void:
	_record_point_statistics(winner)
	var score: Score = match_data.score
	var completed_sets_before: int = score.completed_sets.size()
	var games_before: int = score.games_played
	match_data.add_point(winner)
	if score.games_played > games_before:
		get_player(winner).mental_state.on_game_result(true)
		get_player(1 - winner).mental_state.on_game_result(false)
	_update_players_for_next_point()
	television_hud.update_score(score)
	stadium.show_match_time(match_data.elapsed_seconds)
	if score.is_match_over():
		_end_match(winner)
		return
	umpire.say_score(score)
	cameras.reframe_tv_cameras()
	await get_tree().create_timer(GameConstants.POINT_BREAK).timeout
	if score.completed_sets.size() > completed_sets_before:
		await _hold_set_break()
	await place_players()
	_start_point()


## Position players based on current server and game state
func place_players() -> void:
	var score: Score = match_data.score
	var server_index: int = match_data.get_server()
	var deuce_side: bool = score.is_deuce_court()
	var ends_switched: bool = score.are_ends_switched()

	player0.place_at(
		stadium.positions[_get_player_position(server_index == 0, deuce_side, not ends_switched)]
	)
	# Wait one frame to avoid collisions
	await get_tree().physics_frame
	player1.place_at(
		stadium.positions[_get_player_position(server_index == 1, deuce_side, ends_switched)]
	)
	if player0.global_position.z > 0.0:
		stadium.track_players(player0, player1)
	else:
		stadium.track_players(player1, player0)
	var human_player: Player = _get_single_human_player()
	if human_player:
		cameras.show_from_behind(human_player)


## Starts a point with the first serve. The serve must land on the far half, and the rally
## zone flips from there with every valid bounce.
func _start_point() -> void:
	valid_serve_zone = (
		Court.CourtRegion.BACK_SINGLES_BOX
		if get_server().position.z > 0
		else Court.CourtRegion.FRONT_SINGLES_BOX
	)
	valid_rally_zone = valid_serve_zone
	_point_serve_number = 0
	_point_is_break_point = match_data.score.is_break_point()
	_point_volleyed = [false, false]
	current_state = MatchState.SERVE
	_request_serve()


## Puts the players in position and lets the server serve (first or second serve, or a let).
func _request_serve() -> void:
	match_data.rally_length = 0
	_serve_clipped_net = false
	_stop_players()
	_remove_balls()
	await place_players()
	get_server().request_serve()


## Lets the ball of a missed serve or a let fly on for SERVE_AGAIN_BREAK, no longer counting, then
## serves again.
func _serve_again_after_break() -> void:
	_stop_players()
	_retire_ball()
	await get_tree().create_timer(SERVE_AGAIN_BREAK).timeout
	_request_serve()


func _end_match(winner_index: int) -> void:
	current_state = MatchState.GAME_OVER
	_stop_players()
	_retire_ball()
	match_finished.emit(winner_index)


## Swap rally zone from back to front or vice versa
func _swap_valid_rally_zone() -> void:
	valid_rally_zone = (
		Court.CourtRegion.BACK_SINGLES_BOX
		if valid_rally_zone == Court.CourtRegion.FRONT_SINGLES_BOX
		else Court.CourtRegion.FRONT_SINGLES_BOX
	)


## Handle ball landing on ground (serve, rally, or fault detection)
func _on_ball_on_ground() -> void:
	match current_state:
		MatchState.SERVE, MatchState.SECOND_SERVE:
			_process_serve_ground_contact()
		MatchState.PLAY:
			_process_rally_ground_contact()

	if current_state == MatchState.FAULT:
		_handle_fault()


## A serve in the service box starts the rally; a serve that clipped the net cord on its way
## in is a let and replayed. A first serve out is followed by the second serve, a second
## serve out is a double fault.
func _process_serve_ground_contact() -> void:
	var in_box: bool = court.is_ball_in_court_region(ball.position, _get_valid_service_box())
	if in_box and _serve_clipped_net:
		_serve_again_after_break()
		return

	var is_first_serve: bool = current_state == MatchState.SERVE
	var server_statistics: MatchStatistics = match_data.statistics[match_data.get_server()]
	if is_first_serve:
		server_statistics.first_serves_total += 1
	if in_box:
		if is_first_serve:
			server_statistics.first_serves_in += 1
		_point_serve_number = 1 if is_first_serve else 2
		current_state = MatchState.PLAY
		ground_contacts += 1
		_swap_valid_rally_zone()
		return

	if is_first_serve:
		umpire.say_fault()
		current_state = MatchState.SECOND_SERVE
		_serve_again_after_break()
	else:
		# Double fault: the point ends.
		server_statistics.double_faults += 1
		current_state = MatchState.FAULT


## A bounce in the valid half flips the zone for the next one; a second bounce or a bounce
## outside ends the point.
func _process_rally_ground_contact() -> void:
	if not court.is_ball_in_court_region(ball.position, valid_rally_zone):
		current_state = MatchState.FAULT
		return
	ground_contacts += 1
	if ground_contacts == 1:
		_swap_valid_rally_zone()
	else:
		current_state = MatchState.FAULT


## Ends the point: the last hitter wins it if the ball bounced in, otherwise loses it.
func _handle_fault() -> void:
	_stop_players()
	_retire_ball()
	crowd.cheer(_point_excitement())

	var point_winner: Player
	var last_hitter_statistics: MatchStatistics = match_data.statistics[get_player_index(
		last_hitter
	)]
	if ground_contacts == 0:
		umpire.say_fault()
		point_winner = last_hitter.opponent
		# Out or into the net; a missed second serve is already counted as a double fault.
		if _point_serve_number > 0:
			last_hitter_statistics.errors += 1
	else:
		point_winner = last_hitter
		# Not reached by the opponent; an unreturned serve is counted as an ace.
		if match_data.rally_length > 1:
			last_hitter_statistics.winners += 1

	current_state = MatchState.IDLE
	ground_contacts = 0
	add_point(get_player_index(point_winner))


func _stop_players() -> void:
	player0.stop()
	player1.stop()


## Pauses the match after a set: the music plays and the statistics are shown until
## continue_after_set_break() is called.
func _hold_set_break() -> void:
	var music_director: MusicDirector = get_tree().root.get_node_or_null(^"MusicDirector")
	if music_director:
		music_director.resume()
	set_break_started.emit(match_data.score.completed_sets.size())
	await set_break_ended
	if music_director:
		music_director.stop()


## How exciting the finished point was, in [0, 1]: long rallies, and big points.
func _point_excitement() -> float:
	var rally: float = clampf(
		float(match_data.rally_length - 1) / (MOST_EXCITING_RALLY_SHOTS - 1), 0.0, 1.0
	)
	var big_point_bonus: float = 0.25 if _point_is_break_point else 0.0
	return clampf(rally + big_point_bonus, 0.0, 1.0)


## Records serve, return, net and point statistics for a point won by `winner`.
func _record_point_statistics(winner: int) -> void:
	var server: int = match_data.get_server()
	var receiver: int = 1 - server
	var stats: Array[MatchStatistics] = match_data.statistics
	stats[winner].total_points_won += 1

	match _point_serve_number:
		1:
			stats[server].first_serve_points_played += 1
			if winner == server:
				stats[server].first_serve_points_won += 1
		2:
			stats[server].second_serve_points_played += 1
			if winner == server:
				stats[server].second_serve_points_won += 1
	if _point_serve_number > 0 and match_data.rally_length == 1 and winner == server:
		stats[server].aces += 1

	if _point_is_break_point:
		stats[receiver].break_points_played += 1
		stats[server].break_points_faced += 1
		if winner == receiver:
			stats[receiver].break_points_won += 1
		else:
			stats[server].break_points_saved += 1

	for i in 2:
		if _point_volleyed[i]:
			stats[i].net_points_played += 1
			if winner == i:
				stats[i].net_points_won += 1


## Gets the players ready for the next point: their minds on the score, and as sweaty as the
## match time makes them.
func _update_players_for_next_point() -> void:
	if match_data.score.is_match_over():
		return
	for i in 2:
		var player: Player = get_player(i)
		player.mental_state.before_point(match_data.score, i)
		player.model.sweat_after_match_time(match_data.elapsed_seconds)


## Ends the ball's part in the point: it no longer counts but stays on court until the next
## serve.
func _retire_ball() -> void:
	if not is_instance_valid(ball):
		return
	ball.on_ground.disconnect(_on_ball_on_ground)
	ball.on_net_cord.disconnect(_on_ball_on_net_cord)
	_finished_ball = ball
	ball = null
	active_ball_changed.emit(null)


## Removes the balls from the court when the next serve starts.
func _remove_balls() -> void:
	for old_ball in [ball, _finished_ball]:
		if is_instance_valid(old_ball):
			old_ball.queue_free()
	ball = null
	_finished_ball = null


## Service box the serve must land in: the one diagonal to the server.
func _get_valid_service_box() -> Court.CourtRegion:
	var deuce_side: bool = match_data.score.is_deuce_court()
	if valid_serve_zone == Court.CourtRegion.BACK_SINGLES_BOX:
		return (
			Court.CourtRegion.LEFT_BACK_SERVICE_BOX
			if deuce_side
			else Court.CourtRegion.RIGHT_BACK_SERVICE_BOX
		)
	return (
		Court.CourtRegion.RIGHT_FRONT_SERVICE_BOX
		if deuce_side
		else Court.CourtRegion.LEFT_FRONT_SERVICE_BOX
	)


## The human controlled player when exactly one player is human, otherwise null.
func _get_single_human_player() -> Player:
	var human_players: Array[Player] = []
	for player in [player0, player1]:
		if player.controller is HumanController:
			human_players.append(player)
	return human_players[0] if human_players.size() == 1 else null


## Get the stadium position of a player from its role, the serve side and its end.
## Deuce is the right side as seen from the player's own baseline.
func _get_player_position(
	is_server: bool, serve_from_deuce_side: bool, on_front_end: bool
) -> Stadium.StadiumPosition:
	if on_front_end:
		if is_server:
			return (
				Stadium.StadiumPosition.SERVE_FRONT_RIGHT
				if serve_from_deuce_side
				else Stadium.StadiumPosition.SERVE_FRONT_LEFT
			)
		return (
			Stadium.StadiumPosition.RECEIVE_FRONT_RIGHT
			if serve_from_deuce_side
			else Stadium.StadiumPosition.RECEIVE_FRONT_LEFT
		)
	if is_server:
		return (
			Stadium.StadiumPosition.SERVE_BACK_LEFT
			if serve_from_deuce_side
			else Stadium.StadiumPosition.SERVE_BACK_RIGHT
		)
	return (
		Stadium.StadiumPosition.RECEIVE_BACK_LEFT
		if serve_from_deuce_side
		else Stadium.StadiumPosition.RECEIVE_BACK_RIGHT
	)


## A serve that clips the net cord and lands in the service box is a let and is replayed.
func _on_ball_on_net_cord() -> void:
	if current_state == MatchState.SERVE or current_state == MatchState.SECOND_SERVE:
		_serve_clipped_net = true


func _on_player_serve_requested(serving_player: Player) -> void:
	if serving_player == get_server():
		stadium.start_serve_clocks()
		cameras.frame_return(serving_player.opponent)


func _on_player_serve_completed(serving_player: Player) -> void:
	if serving_player != get_server():
		return
	cameras.settle_after_serve()
	if ball:
		stadium.show_serve_speed(ball)
		match_data.statistics[get_player_index(serving_player)].record_serve_speed(
			ball.velocity.length() * 3.6, current_state == MatchState.SERVE
		)
	stadium.stop_serve_clocks()


func _on_player_ball_hit(player_index: int) -> void:
	var player: Player = get_player(player_index)
	match_data.rally_length += 1
	if player.queued_stroke.is_volley():
		_point_volleyed[player_index] = true
	if current_state == MatchState.PLAY:
		if ground_contacts == 0:
			_swap_valid_rally_zone()
		ground_contacts = 0
	last_hitter = player
