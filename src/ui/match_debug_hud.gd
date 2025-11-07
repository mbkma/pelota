## Debug HUD for displaying match stats and player information during gameplay
extends CanvasLayer

## Reference to match manager for accessing game state
@export var match_manager: MatchManager

## Debug menu display style enumeration
enum Style {
	HIDDEN,  ## Debug menu is hidden
	VISIBLE_COMPACT,  ## Debug menu visible with minimal stats
	VISIBLE_DETAILED,  ## Debug menu visible with all stats
	MAX,  ## Size of enum for wrapping
}

## Current debug menu display style
var _style: Style = Style.HIDDEN:
	set(value):
		_style = value
		match _style:
			Style.HIDDEN:
				visible = false
			Style.VISIBLE_COMPACT, Style.VISIBLE_DETAILED:
				visible = true

# Match state labels
@onready var _match_state_label: Label = $DebugHud/VBoxContainer/MatchState/Value
@onready var _server_label: Label = $DebugHud/VBoxContainer/Server/Value
@onready var _serve_zone_label: Label = $DebugHud/VBoxContainer/ServeZone/Value
@onready var _rally_zone_label: Label = $DebugHud/VBoxContainer/RallyZone/Value
@onready var _ground_contacts_label: Label = $DebugHud/VBoxContainer/GroundContacts/Value
@onready var _last_hitter_label: Label = $DebugHud/VBoxContainer/LastHitter/Value
@onready var _rally_length_label: Label = $DebugHud/VBoxContainer/RallyLength/Value

# Player 0 stat labels
@onready var _p0_name_label: Label = $DebugHud/VBoxContainer/Player0/Name/Value
@onready var _p0_position_label: Label = $DebugHud/VBoxContainer/Player0/Position/Value
@onready var _p0_velocity_label: Label = $DebugHud/VBoxContainer/Player0/Velocity/Value
@onready var _p0_endurance_label: Label = $DebugHud/VBoxContainer/Player0/Endurance/Value
@onready var _p0_speed_label: Label = $DebugHud/VBoxContainer/Player0/Speed/Value

# Player 1 stat labels
@onready var _p1_name_label: Label = $DebugHud/VBoxContainer/Player1/Name/Value
@onready var _p1_position_label: Label = $DebugHud/VBoxContainer/Player1/Position/Value
@onready var _p1_velocity_label: Label = $DebugHud/VBoxContainer/Player1/Velocity/Value
@onready var _p1_endurance_label: Label = $DebugHud/VBoxContainer/Player1/Endurance/Value
@onready var _p1_speed_label: Label = $DebugHud/VBoxContainer/Player1/Speed/Value

# Ball stat labels
@onready var _ball_position_label: Label = $DebugHud/VBoxContainer/Ball/Position/Value
@onready var _ball_velocity_label: Label = $DebugHud/VBoxContainer/Ball/Velocity/Value


## Handle debug menu toggle input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_debug_menu"):
		_style = wrapi(_style + 1, 0, Style.MAX) as Style


## Update debug display each frame if visible
func _process(_delta: float) -> void:
	if visible:
		_update_match_stats()
		if _style == Style.VISIBLE_DETAILED:
			_update_player_stats()
			_update_ball_stats()


## Update match state statistics display
func _update_match_stats() -> void:
	_match_state_label.text = _match_state_to_string(match_manager.current_state)

	var server_idx: int = match_manager.match_data.match_score.current_server
	var server_name: String = (
		match_manager.player0.player_data.last_name
		if server_idx == 0
		else match_manager.player1.player_data.last_name
	)
	_server_label.text = server_name

	_serve_zone_label.text = _court_region_to_string(match_manager._valid_serve_zone)
	_rally_zone_label.text = _court_region_to_string(match_manager._valid_rally_zone)
	_ground_contacts_label.text = str(match_manager._ground_contacts)
	_rally_length_label.text = str(match_manager.match_data.rally_length)

	if match_manager.last_hitter:
		_last_hitter_label.text = match_manager.last_hitter.player_data.last_name
	else:
		_last_hitter_label.text = "None"


## Update player position, velocity, and stat displays
func _update_player_stats() -> void:
	# Player 0 stats
	var p0: Player = match_manager.player0
	_p0_name_label.text = p0.player_data.last_name
	_p0_position_label.text = "%.2f, %.2f, %.2f" % [p0.position.x, p0.position.y, p0.position.z]
	_p0_velocity_label.text = "%.2f" % p0.velocity.length()
	_p0_endurance_label.text = str(p0.player_data.stats.get("endurance", 0))
	_p0_speed_label.text = str(p0.player_data.stats.get("speed", 0))

	# Player 1 stats
	var p1: Player = match_manager.player1
	_p1_name_label.text = p1.player_data.last_name
	_p1_position_label.text = "%.2f, %.2f, %.2f" % [p1.position.x, p1.position.y, p1.position.z]
	_p1_velocity_label.text = "%.2f" % p1.velocity.length()
	_p1_endurance_label.text = str(p1.player_data.stats.get("endurance", 0))
	_p1_speed_label.text = str(p1.player_data.stats.get("speed", 0))


## Update ball position and velocity display
func _update_ball_stats() -> void:
	if match_manager.ball:
		var ball: Ball = match_manager.ball
		_ball_position_label.text = (
			"%.2f, %.2f, %.2f" % [ball.position.x, ball.position.y, ball.position.z]
		)
		_ball_velocity_label.text = "%.2f" % ball.velocity.length()


## Convert court region enum to human-readable string
func _court_region_to_string(value: Court.CourtRegion) -> String:
	var enum_map: Dictionary[Court.CourtRegion, String] = {
		Court.CourtRegion.LEFT_FRONT_SERVICE_BOX: "LEFT_FRONT_SERVICE_BOX",
		Court.CourtRegion.RIGHT_FRONT_SERVICE_BOX: "RIGHT_FRONT_SERVICE_BOX",
		Court.CourtRegion.LEFT_BACK_SERVICE_BOX: "LEFT_BACK_SERVICE_BOX",
		Court.CourtRegion.RIGHT_BACK_SERVICE_BOX: "RIGHT_BACK_SERVICE_BOX",
		Court.CourtRegion.BACK_SINGLES_BOX: "BACK_SINGLES_BOX",
		Court.CourtRegion.FRONT_SINGLES_BOX: "FRONT_SINGLES_BOX"
	}
	return enum_map.get(value, "UNKNOWN")


## Convert match state enum to human-readable string
func _match_state_to_string(value: MatchManager.MatchState) -> String:
	var enum_map: Dictionary[MatchManager.MatchState, String] = {
		MatchManager.MatchState.NOT_STARTED: "NOT_STARTED",
		MatchManager.MatchState.IDLE: "IDLE",
		MatchManager.MatchState.SERVE: "SERVE",
		MatchManager.MatchState.SECOND_SERVE: "SECOND_SERVE",
		MatchManager.MatchState.PLAY: "PLAY",
		MatchManager.MatchState.FAULT: "FAULT",
		MatchManager.MatchState.GAME_OVER: "GAME_OVER",
	}
	return enum_map.get(value, "UNKNOWN")
