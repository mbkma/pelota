class_name ReplayOverlay
extends CanvasLayer

@export var match_manager: MatchManager

@onready var _top_label: Label = $TopLabel
@onready var _status_label: Label = $BottomBar/Margin/HBox/Status
@onready var _play_pause_button: Button = $BottomBar/Margin/HBox/PlayPauseButton
@onready var _rewind_button: Button = $BottomBar/Margin/HBox/RewindButton
@onready var _prev_frame_button: Button = $BottomBar/Margin/HBox/PrevFrameButton
@onready var _next_frame_button: Button = $BottomBar/Margin/HBox/NextFrameButton
@onready var _forward_button: Button = $BottomBar/Margin/HBox/ForwardButton
@onready var _stop_button: Button = $BottomBar/Margin/HBox/StopButton
@onready var _exit_replay_button: Button = $BottomBar/Margin/HBox/ExitReplayButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if not match_manager:
		match_manager = get_parent().get_node_or_null("MatchManager") as MatchManager

	_play_pause_button.pressed.connect(_on_play_pause_pressed)
	_rewind_button.pressed.connect(_on_rewind_pressed)
	_prev_frame_button.pressed.connect(_on_prev_frame_pressed)
	_next_frame_button.pressed.connect(_on_next_frame_pressed)
	_forward_button.pressed.connect(_on_forward_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_exit_replay_button.pressed.connect(_on_exit_replay_pressed)

	_connect_signals()
	_refresh_ui()


func _connect_signals() -> void:
	if not match_manager:
		return

	if not match_manager.replay_started.is_connected(_on_replay_visibility_changed):
		match_manager.replay_started.connect(_on_replay_visibility_changed)
	if not match_manager.replay_stopped.is_connected(_on_replay_visibility_changed):
		match_manager.replay_stopped.connect(_on_replay_visibility_changed)
	if not match_manager.replay_finished.is_connected(_on_replay_visibility_changed):
		match_manager.replay_finished.connect(_on_replay_visibility_changed)
	if not match_manager.replay_paused.is_connected(_on_replay_visibility_changed):
		match_manager.replay_paused.connect(_on_replay_visibility_changed)
	if not match_manager.replay_resumed.is_connected(_on_replay_visibility_changed):
		match_manager.replay_resumed.connect(_on_replay_visibility_changed)


func _on_replay_visibility_changed(_value = null) -> void:
	_refresh_ui()


func _on_play_pause_pressed() -> void:
	if not match_manager:
		return
	match_manager.toggle_replay_pause()
	_refresh_ui()


func _on_rewind_pressed() -> void:
	if not match_manager:
		return
	match_manager.rewind_replay(2.0)
	_refresh_ui()


func _on_forward_pressed() -> void:
	if not match_manager:
		return
	match_manager.forward_replay(2.0)
	_refresh_ui()


func _on_prev_frame_pressed() -> void:
	if not match_manager:
		return
	match_manager.step_replay_frame(-1)
	_refresh_ui()


func _on_next_frame_pressed() -> void:
	if not match_manager:
		return
	match_manager.step_replay_frame(1)
	_refresh_ui()


func _on_stop_pressed() -> void:
	if not match_manager:
		return
	match_manager.stop_replay()
	_refresh_ui()


func _on_exit_replay_pressed() -> void:
	if not match_manager:
		return
	match_manager.stop_replay()
	var pause_menu: PauseMenu = get_parent().get_node_or_null("PauseMenu") as PauseMenu
	if pause_menu:
		pause_menu.pause_game()
	_refresh_ui()


func _process(_delta: float) -> void:
	if visible:
		_refresh_ui()


func _refresh_ui() -> void:
	if not match_manager:
		visible = false
		return

	var replay_active: bool = match_manager.is_replay_playing()
	visible = replay_active
	if not replay_active:
		return

	_top_label.text = "REPLAY"
	var playhead: float = match_manager.get_replay_playhead_seconds()
	var duration: float = match_manager.get_replay_duration_seconds()
	var progress: float = match_manager.get_replay_progress() * 100.0
	_status_label.text = "%.2fs / %.2fs (%.0f%%)" % [playhead, duration, progress]
	_play_pause_button.text = "Resume" if match_manager.is_replay_paused() else "Pause"
