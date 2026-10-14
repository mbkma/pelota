## The pause menu's window that hands the players to other input devices, the same way as the
## player select menu (see DeviceLanes): moving a device left or right gives it the player of
## that side, a player without a device is played by the CPU. Closing the window hands the
## players over (see Player). With `one_player` (training, tournament) only player 1 changes
## hands, and only to a device.
@tool
class_name ControllersWindow
extends OverlaidWindow

## Only player 1's lane, which needs a device
@export var one_player: bool = false
## Hint over the lanes with two players and with one
@export_multiline var two_players_text: String
@export_multiline var one_player_text: String

@onready var _device_lanes: DeviceLanes = %DeviceLanes


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	opened.connect(_on_opened)
	closed.connect(_on_closed)
	_device_lanes.changed.connect(_refresh_close_button)


func _on_opened() -> void:
	_device_lanes.one_player = one_player
	description_label.text = one_player_text if one_player else two_players_text
	_device_lanes.assign(
		GlobalGameData.get_match_input_device(0), GlobalGameData.get_match_input_device(1)
	)


## Hands the players to the devices in their lanes; with one player only if a device is in
## player 1's lane (else nothing changes).
func _on_closed() -> void:
	var player1_device_id: int = _device_lanes.get_lane_device_id(DeviceLanes.Lane.PLAYER1)
	if one_player and player1_device_id == InputDevice.NO_DEVICE_ID:
		return
	var player2_device_id: int = (
		GlobalGameData.get_match_input_device(1)
		if one_player
		else _device_lanes.get_lane_device_id(DeviceLanes.Lane.PLAYER2)
	)
	GlobalGameData.set_match_input_devices(player1_device_id, player2_device_id)


func _refresh_close_button() -> void:
	close_button.disabled = (
		one_player
		and _device_lanes.get_lane_device_id(DeviceLanes.Lane.PLAYER1) == InputDevice.NO_DEVICE_ID
	)
