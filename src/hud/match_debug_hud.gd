extends CanvasLayer

@export var match_manager: MatchManager

@onready var state: Label = $DebugHud/VBoxContainer/State
@onready var valid_serve_zone: Label = $DebugHud/VBoxContainer/ValidServeZone
@onready var valid_rally_zone: Label = $DebugHud/VBoxContainer/ValidRallyZone

## Debug menu display style.
enum Style {
	HIDDEN,  ## Debug menu is hidden.
	VISIBLE_COMPACT,  ## Debug menu is visible, with only the FPS, FPS cap (if any) and time taken to render the last frame.
	VISIBLE_DETAILED,  ## Debug menu is visible with full information, including graphs.
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
				state.visible = style >= Style.VISIBLE_COMPACT

# Value of `Time.get_ticks_usec()` on the previous frame.
var last_tick := 0

## Returns the sum of all values of an array (use as a parameter to `Array.reduce()`).
var sum_func := func avg(accum: float, number: float) -> float: return accum + number

# History of the last `HISTORY_NUM_FRAMES` rendered frames.
var frame_history_total: Array[float] = []
var frame_history_cpu: Array[float] = []
var frame_history_gpu: Array[float] = []
var fps_history: Array[float] = []  # Only used for graphs.

var frame_time_gradient := Gradient.new()


func _ready() -> void:
	# NOTE: Both FPS and frametimes are colored following FPS logic
	# (red = 10 FPS, yellow = 60 FPS, green = 110 FPS, cyan = 160 FPS).
	# This makes the color gradient non-linear.
	# Colors are taken from <https://tailwindcolor.com/>.
	frame_time_gradient.set_color(0, Color8(239, 68, 68))  # red-500
	frame_time_gradient.set_color(1, Color8(56, 189, 248))  # light-blue-400
	frame_time_gradient.add_point(0.3333, Color8(250, 204, 21))  # yellow-400
	frame_time_gradient.add_point(0.6667, Color8(128, 226, 95))  # 50-50 mix of lime-400 and green-400


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_debug_menu"):
		style = wrapi(style + 1, 0, Style.MAX) as Style


func _process(_delta: float) -> void:
	if visible:
		# Difference between the last two rendered frames in milliseconds.
		state.text = "Current state: " + match_state_to_string(match_manager.current_state)
		valid_serve_zone.text = (
			"Valid Serve Zone: " + court_region_to_string(match_manager._valid_serve_zone)
		)
		valid_rally_zone.text = (
			"Valid Rally Zone: " + court_region_to_string(match_manager._valid_rally_zone)
		)
		valid_rally_zone.text = ("Ground Contacts: " + str(match_manager._ground_contacts))
		if match_manager.last_hitter:
			valid_rally_zone.text = (
				"Last Hitter: " + str(match_manager.last_hitter.player_data.last_name)
			)


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


func _on_visibility_changed() -> void:
	if visible:
		# Reset graphs to prevent them from looking strange before `HISTORY_NUM_FRAMES` frames
		# have been drawn.
		var frametime_last := (Time.get_ticks_usec() - last_tick) * 0.001

		var viewport_rid := get_viewport().get_viewport_rid()
		frame_history_cpu.fill(
			(
				RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
				+ RenderingServer.get_frame_setup_time_cpu()
			)
		)
		frame_history_gpu.fill(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
