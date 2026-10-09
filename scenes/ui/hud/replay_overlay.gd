## Playback controls shown while a replay plays; the keyboard or gamepad moves between them.
class_name ReplayOverlay
extends CanvasLayer

@export var replay: MatchReplayController

@onready var _status_label: Label = $BottomBar/Margin/HBox/Status
@onready var _play_pause_button: Button = $BottomBar/Margin/HBox/PlayPauseButton


func _ready() -> void:
	visible = false
	$BottomBar/Margin/HBox/RewindButton.pressed.connect(replay.rewind)
	$BottomBar/Margin/HBox/PrevFrameButton.pressed.connect(replay.step_frame.bind(-1))
	_play_pause_button.pressed.connect(replay.toggle_pause)
	$BottomBar/Margin/HBox/NextFrameButton.pressed.connect(replay.step_frame.bind(1))
	$BottomBar/Margin/HBox/ForwardButton.pressed.connect(replay.forward)
	$BottomBar/Margin/HBox/StopButton.pressed.connect(replay.stop_playback)
	replay.playback_started.connect(_on_playback_started)
	replay.playback_stopped.connect(hide)


func _process(_delta: float) -> void:
	if not visible:
		return
	var playhead: float = replay.get_playhead_seconds()
	var duration: float = replay.get_duration_seconds()
	var progress: float = 100.0 * playhead / duration if duration > 0.0 else 0.0
	_status_label.text = "%.2fs / %.2fs (%.0f%%)" % [playhead, duration, progress]
	_play_pause_button.text = "Resume" if replay.is_paused() else "Pause"


func _on_playback_started() -> void:
	show()
	_play_pause_button.grab_focus()
