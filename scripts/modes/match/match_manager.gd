## Manages match state, scoring, and game flow for tennis matches
class_name MatchManager
extends Node

## Emitted when players have been positioned
signal players_placed

enum MatchState { NOT_STARTED, IDLE, SERVE, SECOND_SERVE, PLAY, FAULT, GAME_OVER }

## Reference to the last player who hit the ball
var last_hitter: Player

## History of all match state changes
var state_history: Array[MatchState] = []

## Current match state (use setter to trigger state_changed signal)
var current_state: MatchState = MatchState.NOT_STARTED:
	set(value):
		state_history.append(value)
		current_state = value

## Valid service zone for current serve
var _valid_serve_zone: Court.CourtRegion

## Valid rally zone for current rally
var _valid_rally_zone: Court.CourtRegion

## Number of ground contacts in current rally
var _ground_contacts: int = 0

@onready var match_data: MatchData

@export var player0: Player
@export var player1: Player
@export var ball: Ball
@export var court: Court
@export var stadium: Stadium
@export var television_hud: TelevisionHud
@export var umpire: Umpire
@export var crowd: Crowd
@export var cameras: MatchCameras

func _ready() -> void:
	if not player0 or not player1 or not court or not stadium or not television_hud:
		push_error("MatchManager not properly initialized! Missing required nodes.")
		return

	# Set opponent references for each player
	player0.opponent = player1
	player1.opponent = player0

	match_data = MatchData.new(player0.player_data, player1.player_data)
	player0.ball_hit.connect(_on_player0_ball_hit)
	player1.ball_hit.connect(_on_player1_ball_hit)
	player0.just_served.connect(_on_player_just_served)
	player1.just_served.connect(_on_player_just_served)
	player0.ball_spawned.connect(_on_player_ball_spawned)
	player1.ball_spawned.connect(_on_player_ball_spawned)
	television_hud.score_display.player_1_score_panel.set_player(player0.player_data)
	television_hud.score_display.player_2_score_panel.set_player(player1.player_data)
	
	cameras.register_camera(player0.first_person_camera)
	cameras.register_camera(player1.first_person_camera)
	cameras.player0 = player0
	cameras.player1 = player1
	place_players()
	start_match()


## Handle debug input (T key to add point for testing)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			add_point(randi() % 2)


## Set active ball and connect its signals
func set_active_ball(b: Ball) -> void:
	ball = b
	ball.on_ground.connect(_on_ball_on_ground)
	ball.on_net.connect(_on_ball_on_net)

## Get the opponent of the given player
func get_opponent(player: Player) -> Player:
	if player == player0:
		return player1
	return player0


## Get the index (0 or 1) of the given player
func get_player_index(player: Player) -> int:
	if player == player0:
		return 0
	return 1


## Request the current server to serve
func set_player_serve() -> void:
	_stop_players()
	_clear_ball()
	place_players()
	await players_placed
	if match_data.get_server() == 0:
		player0.request_serve()
	else:
		player1.request_serve()


## Start a new match
func start_match() -> void:
	_valid_serve_zone = (
		Court.CourtRegion.BACK_SINGLES_BOX
		if get_server().position.z > 0
		else Court.CourtRegion.FRONT_SINGLES_BOX
	)
	_valid_rally_zone = _valid_serve_zone
	current_state = MatchState.SERVE
	set_player_serve()


## End the match
func end_match(_winner: String) -> void:
	current_state = MatchState.GAME_OVER


## Reset match to starting state
func reset_match() -> void:
	current_state = MatchState.NOT_STARTED


## Swap rally zone from back to front or vice versa
func _swap_valid_rally_zone() -> void:
	_valid_rally_zone = (
		Court.CourtRegion.BACK_SINGLES_BOX
		if _valid_rally_zone == Court.CourtRegion.FRONT_SINGLES_BOX
		else Court.CourtRegion.FRONT_SINGLES_BOX
	)


## Handle ball landing on ground (serve, rally, or fault detection)
func _on_ball_on_ground() -> void:
	if current_state == MatchState.IDLE:
		return
	if current_state == MatchState.SERVE:
		_process_serve_ground_contact()
	elif current_state == MatchState.SECOND_SERVE:
		_process_second_serve_ground_contact()
	elif current_state == MatchState.PLAY:
		_process_rally_ground_contact()

	if current_state == MatchState.FAULT:
		_handle_fault()


## Process ground contact during first serve
func _process_serve_ground_contact() -> void:
	var valid_box: Court.CourtRegion = get_valid_service_box()
	if court.is_ball_in_court_region(ball.position, valid_box):
		current_state = MatchState.PLAY
		_ground_contacts += 1
		_swap_valid_rally_zone()
	else:
		current_state = MatchState.SECOND_SERVE
		_clear_ball()
		if umpire:
			umpire.say_second_serve()
		set_player_serve()


## Process ground contact during second serve
func _process_second_serve_ground_contact() -> void:
	var valid_box: Court.CourtRegion = get_valid_service_box()
	if court.is_ball_in_court_region(ball.position, valid_box):
		current_state = MatchState.PLAY
		_ground_contacts += 1
		_swap_valid_rally_zone()
	else:
		current_state = MatchState.FAULT


## Process ground contact during rally play
func _process_rally_ground_contact() -> void:
	if court.is_ball_in_court_region(ball.position, _valid_rally_zone):
		_ground_contacts += 1
		if _ground_contacts < GameConstants.GROUND_CONTACT_THRESHOLD:
			_swap_valid_rally_zone()
		else:
			current_state = MatchState.FAULT
	else:
		current_state = MatchState.FAULT


## Handle fault condition (out of bounds or double fault)
func _handle_fault() -> void:
	_stop_players()
	_clear_ball()
	if umpire:
		if _ground_contacts == 0:
			umpire.say_fault()

	if crowd:
		crowd.play_victory()

	var point_winner: Player
	if _ground_contacts == 0:
		point_winner = get_opponent(last_hitter)
	else:
		point_winner = last_hitter

	current_state = MatchState.IDLE
	_valid_rally_zone = _valid_serve_zone
	_ground_contacts = 0
	add_point(get_player_index(point_winner))


## Stop both players' movement and actions
func _stop_players() -> void:
	player0.stop()
	player1.stop()


## Handle ball hitting the net during serve
func _on_ball_on_net() -> void:
	pass
	#if current_state == MatchState.SERVE:
		##current_state = MatchState.SECOND_SERVE
		##_clear_ball()
		##if umpire:
			##umpire.say_second_serve()
		##set_player_serve()
	#elif current_state == MatchState.SECOND_SERVE:
		#current_state = MatchState.FAULT


## Add a point to the winner and handle score update
func add_point(winner: int) -> void:
	match_data.add_point(winner)
	television_hud.update_score(match_data.get_score())
	if umpire:
		umpire.say_score(match_data.get_score())
	await (
		get_tree()
		. create_timer(GameConstants.FAULT_DELAY + GameConstants.POINT_RESET_EXTRA_DELAY)
		. timeout
	)
	place_players()
	await players_placed
	_valid_serve_zone = (
		Court.CourtRegion.BACK_SINGLES_BOX
		if get_server().position.z > 0
		else Court.CourtRegion.FRONT_SINGLES_BOX
	)
	current_state = MatchState.SERVE
	set_player_serve()


## Get the current server player
func get_server() -> Player:
	var server_index: int = match_data.match_score.current_server
	if server_index == 0:
		return player0
	return player1


## Clear ball signals
func _clear_ball() -> void:
	if ball:
		if ball.on_ground.is_connected(_on_ball_on_ground):
			ball.on_ground.disconnect(_on_ball_on_ground)
		if ball.on_net.is_connected(_on_ball_on_net):
			ball.on_net.disconnect(_on_ball_on_net)


## Check if server serves from deuce side (even total points)
func is_serve_from_deuce_side() -> bool:
	var score = match_data.get_score()
	var total_points: int = score.points[0] + score.points[1]
	return (total_points % 2) == 0


## Get the valid service box for current serve
func get_valid_service_box() -> Court.CourtRegion:
	var serve_from_deuce_side: bool = is_serve_from_deuce_side()

	var valid_service_box: Court.CourtRegion
	if _valid_serve_zone == Court.CourtRegion.BACK_SINGLES_BOX:
		valid_service_box = (
			Court.CourtRegion.LEFT_BACK_SERVICE_BOX
			if serve_from_deuce_side
			else Court.CourtRegion.RIGHT_BACK_SERVICE_BOX
		)
	else:
		valid_service_box = (
			Court.CourtRegion.RIGHT_FRONT_SERVICE_BOX
			if serve_from_deuce_side
			else Court.CourtRegion.LEFT_FRONT_SERVICE_BOX
		)

	return valid_service_box


## Position players based on current server and game state
func place_players() -> void:
	var server_index: int = match_data.get_server()
	var score = match_data.get_score()
	var total_games: int = score.games[0] + score.games[1]
	var switch_sides: bool = (
		(total_games % GameConstants.SIDE_SWITCH_GAME_CYCLE) == 1
		or (total_games % GameConstants.SIDE_SWITCH_GAME_CYCLE) == 2
	)
	var serve_from_deuce_side: bool = is_serve_from_deuce_side()

	# Determine player positions
	var player0_position: Stadium.StadiumPosition = _get_player_position(
		server_index == 0, serve_from_deuce_side, switch_sides, true
	)
	var player1_position: Stadium.StadiumPosition = _get_player_position(
		server_index == 1, serve_from_deuce_side, switch_sides, false
	)

	# Assign positions to players using stadium positions dictionary
	player0.global_position = stadium.positions[player0_position]
	# Wait one frame to avoid collisions
	await get_tree().physics_frame
	player1.global_position = stadium.positions[player1_position]
	player0.rotation.y = PI if player0.position.z < 0 else 0.0
	player1.rotation.y = PI if player1.position.z < 0 else 0.0
	players_placed.emit()
	cameras.set_camera_for_player(player0)
	cameras.set_camera_for_player(player1)

## Get position for a player based on serve and side information
func _get_player_position(
	is_server: bool, serve_from_deuce_side: bool, switch_sides: bool, _is_player0: bool
) -> Stadium.StadiumPosition:
	if is_server:
		if switch_sides:
			# Server is on back side
			return (
				stadium.StadiumPosition.SERVE_BACK_LEFT
				if serve_from_deuce_side
				else stadium.StadiumPosition.SERVE_BACK_RIGHT
			)
		# Server is on front side
		return (
			stadium.StadiumPosition.SERVE_FRONT_RIGHT
			if serve_from_deuce_side
			else stadium.StadiumPosition.SERVE_FRONT_LEFT
		)
	# Receiver
	if switch_sides:
		return (
			stadium.StadiumPosition.RECEIVE_FRONT_RIGHT
			if serve_from_deuce_side
			else stadium.StadiumPosition.RECEIVE_FRONT_LEFT
		)
	return (
		stadium.StadiumPosition.RECEIVE_BACK_LEFT
		if serve_from_deuce_side
		else stadium.StadiumPosition.RECEIVE_BACK_RIGHT
	)


## Signal Callbacks
####################


func _on_player_ball_spawned(b: Ball) -> void:
	if ball:
		_clear_ball()
		ball.queue_free()
	set_active_ball(b)

## Called when a player just served
func _on_player_just_served() -> void:
	stadium.show_serve_speed(ball)
	stadium.stop_serve_clocks()


## Called when player 0 hits the ball
func _on_player0_ball_hit() -> void:
	if current_state == MatchState.PLAY:
		if _ground_contacts == 0:
			_swap_valid_rally_zone()
		_ground_contacts = 0
	last_hitter = player0


## Called when player 1 hits the ball
func _on_player1_ball_hit() -> void:
	if current_state == MatchState.PLAY:
		if _ground_contacts == 0:
			_swap_valid_rally_zone()
		_ground_contacts = 0
	last_hitter = player1
