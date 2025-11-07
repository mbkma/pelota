extends CanvasLayer

@export var match_manager: MatchManager

## Debug menu display style.
enum Style {
	HIDDEN,  ## Debug menu is hidden.
	VISIBLE_COMPACT,  ## Debug menu is visible with minimal info.
	VISIBLE_DETAILED,  ## Debug menu is visible with full information.
	MAX,  ## Represents the size of the Style enum.
}

## The style to use when drawing the debug menu.
var style := Style.HIDDEN:
	set(value):
		style = value
		match style:
			Style.HIDDEN:
				visible = false
			Style.VISIBLE_COMPACT, Style.VISIBLE_DETAILED:
				visible = true

# Node references - Match Stats
@onready var match_state_label: Label = $DebugHud/VBoxContainer/MatchState/Value
@onready var server_label: Label = $DebugHud/VBoxContainer/Server/Value
@onready var serve_zone_label: Label = $DebugHud/VBoxContainer/ServeZone/Value
@onready var rally_zone_label: Label = $DebugHud/VBoxContainer/RallyZone/Value
@onready var ground_contacts_label: Label = $DebugHud/VBoxContainer/GroundContacts/Value
@onready var last_hitter_label: Label = $DebugHud/VBoxContainer/LastHitter/Value
@onready var rally_length_label: Label = $DebugHud/VBoxContainer/RallyLength/Value

# Player 0 labels
@onready var p0_name_label: Label = $DebugHud/VBoxContainer/Player0/Name/Value
@onready var p0_position_label: Label = $DebugHud/VBoxContainer/Player0/Position/Value
@onready var p0_velocity_label: Label = $DebugHud/VBoxContainer/Player0/Velocity/Value
@onready var p0_endurance_label: Label = $DebugHud/VBoxContainer/Player0/Endurance/Value
@onready var p0_speed_label: Label = $DebugHud/VBoxContainer/Player0/Speed/Value

# Player 1 labels
@onready var p1_name_label: Label = $DebugHud/VBoxContainer/Player1/Name/Value
@onready var p1_position_label: Label = $DebugHud/VBoxContainer/Player1/Position/Value
@onready var p1_velocity_label: Label = $DebugHud/VBoxContainer/Player1/Velocity/Value
@onready var p1_endurance_label: Label = $DebugHud/VBoxContainer/Player1/Endurance/Value
@onready var p1_speed_label: Label = $DebugHud/VBoxContainer/Player1/Speed/Value

# Ball labels
@onready var ball_position_label: Label = $DebugHud/VBoxContainer/Ball/Position/Value
@onready var ball_velocity_label: Label = $DebugHud/VBoxContainer/Ball/Velocity/Value


func _ready() -> void:
	pass


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_debug_menu"):
		style = wrapi(style + 1, 0, Style.MAX) as Style


func _process(_delta: float) -> void:
	if visible:
		update_match_stats()
		if style == Style.VISIBLE_DETAILED:
			update_player_stats()
			update_ball_stats()


func update_match_stats() -> void:
	match_state_label.text = match_state_to_string(match_manager.current_state)

	var server_idx = match_manager.match_data.get_server()
	var server_name = match_manager.player0.player_data.last_name if server_idx == 0 else match_manager.player1.player_data.last_name
	server_label.text = server_name

	serve_zone_label.text = court_region_to_string(match_manager._valid_serve_zone)
	rally_zone_label.text = court_region_to_string(match_manager._valid_rally_zone)
	ground_contacts_label.text = str(match_manager._ground_contacts)
	rally_length_label.text = str(match_manager.match_data.rally_length)

	if match_manager.last_hitter:
		last_hitter_label.text = match_manager.last_hitter.player_data.last_name
	else:
		last_hitter_label.text = "None"


func update_player_stats() -> void:
	# Player 0
	var p0 = match_manager.player0
	p0_name_label.text = p0.player_data.last_name
	p0_position_label.text = "%.2f, %.2f, %.2f" % [p0.position.x, p0.position.y, p0.position.z]
	p0_velocity_label.text = "%.2f" % p0.velocity.length()
	p0_endurance_label.text = str(p0.player_data.stats.get("endurance", 0))
	p0_speed_label.text = str(p0.player_data.stats.get("speed", 0))

	# Player 1
	var p1 = match_manager.player1
	p1_name_label.text = p1.player_data.last_name
	p1_position_label.text = "%.2f, %.2f, %.2f" % [p1.position.x, p1.position.y, p1.position.z]
	p1_velocity_label.text = "%.2f" % p1.velocity.length()
	p1_endurance_label.text = str(p1.player_data.stats.get("endurance", 0))
	p1_speed_label.text = str(p1.player_data.stats.get("speed", 0))


func update_ball_stats() -> void:
	if match_manager.ball:
		var ball = match_manager.ball
		ball_position_label.text = "%.2f, %.2f, %.2f" % [ball.position.x, ball.position.y, ball.position.z]
		ball_velocity_label.text = "%.2f" % ball.velocity.length()


func court_region_to_string(value: Court.CourtRegion) -> String:
	var enum_map := {
		Court.CourtRegion.LEFT_FRONT_SERVICE_BOX: "LEFT_FRONT_SERVICE_BOX",
		Court.CourtRegion.RIGHT_FRONT_SERVICE_BOX: "RIGHT_FRONT_SERVICE_BOX",
		Court.CourtRegion.LEFT_BACK_SERVICE_BOX: "LEFT_BACK_SERVICE_BOX",
		Court.CourtRegion.RIGHT_BACK_SERVICE_BOX: "RIGHT_BACK_SERVICE_BOX",
		Court.CourtRegion.BACK_SINGLES_BOX: "BACK_SINGLES_BOX",
		Court.CourtRegion.FRONT_SINGLES_BOX: "FRONT_SINGLES_BOX"
	}
	return enum_map.get(value, "UNKNOWN")


func match_state_to_string(value: MatchManager.MatchState) -> String:
	var enum_map := {
		MatchManager.MatchState.NOT_STARTED: "NOT_STARTED",
		MatchManager.MatchState.IDLE: "IDLE",
		MatchManager.MatchState.SERVE: "SERVE",
		MatchManager.MatchState.SECOND_SERVE: "SECOND_SERVE",
		MatchManager.MatchState.PLAY: "PLAY",
		MatchManager.MatchState.FAULT: "FAULT",
		MatchManager.MatchState.GAME_OVER: "GAME_OVER",
	}
	return enum_map.get(value, "UNKNOWN")
