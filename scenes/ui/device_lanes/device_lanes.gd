## Device lanes, used by the player select menu and the pause menu. Every connected input device
## is a row with a slot per lane: player 1 on the left, the CPU in the middle and player 2 on the
## right (no player 2 lane with `one_player`). Moving a device left or right (stick, d-pad, WASD
## or arrow keys) moves it into the next lane; a side holds one device. With
## `needs_confirmation` a device on a side confirms with its accept button (A / Enter) and shows
## READY; cancel takes the confirmation back (see handle_cancel). Up and down on a device on a
## side ask for the side's next character (character_step_requested).
class_name DeviceLanes
extends VBoxContainer

## A device moved, was confirmed, or devices were plugged in or out
signal changed
## A device on `lane` asks for the previous (`step` -1) or next (1) character
signal character_step_requested(lane: Lane, step: int)

enum Lane {
	PLAYER1,
	UNASSIGNED,
	PLAYER2,
}

@export var device_row_scene: PackedScene
## Only player 1's lane and the CPU lane (training, tournament)
@export var one_player: bool = false:
	set(value):
		one_player = value
		if is_node_ready():
			_player2_lane_label.visible = not one_player
			_rebuild_rows()
## Whether a device on a side has to confirm (see the top of the file)
@export var needs_confirmation: bool = true
## Icon colors of the devices in each lane, in Lane order
@export var lane_colors: Array[Color] = [Palette.PLAYER_1, Palette.CREAM, Palette.PLAYER_2]
## Direction length that moves a device
@export_range(0.0, 1.0) var direction_trigger: float = 0.6
## Direction length below which the direction counts as neutral again
@export_range(0.0, 1.0) var direction_release: float = 0.3

var _rows: Array[DeviceRow] = []
## Devices whose cancel press took back a confirmation; their cancel release is swallowed so
## it does not also leave the menu.
var _cancel_consumed_device_ids: Array[int] = []

@onready var _player2_lane_label: Label = %Player2LaneLabel
@onready var _device_rows: VBoxContainer = %DeviceRows


func _ready() -> void:
	_player2_lane_label.visible = not one_player
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Devices only move while the lanes are shown.
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree())
	_rebuild_rows()


## Puts `player1_device_id` and `player2_device_id` (InputDevice.NO_DEVICE_ID for the CPU) on
## their sides, confirmed, and every other device in the middle.
func assign(player1_device_id: int, player2_device_id: int) -> void:
	for row in _rows:
		var device_id: int = row.device.get_device_id()
		var lane: Lane = Lane.UNASSIGNED
		if device_id == player1_device_id:
			lane = Lane.PLAYER1
		elif device_id == player2_device_id and not one_player:
			lane = Lane.PLAYER2
		row.place(lane, lane_colors[lane])
		row.set_confirmed(lane != Lane.UNASSIGNED and needs_confirmation)
		row.latched = true
	changed.emit()


## The device on `lane`, InputDevice.NO_DEVICE_ID for the CPU.
func get_lane_device_id(lane: Lane) -> int:
	var row: DeviceRow = _lane_row(lane)
	return row.device.get_device_id() if row else InputDevice.NO_DEVICE_ID


## Name of the device on `lane`, empty for the CPU.
func get_lane_device_name(lane: Lane) -> String:
	var row: DeviceRow = _lane_row(lane)
	return row.device.get_display_name() if row else ""


func is_lane_confirmed(lane: Lane) -> bool:
	var row: DeviceRow = _lane_row(lane)
	return row != null and row.confirmed


## Whether every device on a side has confirmed.
func are_sides_confirmed() -> bool:
	for lane in [Lane.PLAYER1, Lane.PLAYER2]:
		var row: DeviceRow = _lane_row(lane)
		if row and not row.confirmed:
			return false
	return true


## Takes back the confirmation of the device that pressed cancel. Returns whether the event was
## used, i.e. it must not leave the menu.
func handle_cancel(event: InputEvent) -> bool:
	var device_id: int = KeyboardInput.DEVICE_ID if event is InputEventKey else event.device
	if event.is_released():
		if not _cancel_consumed_device_ids.has(device_id):
			return false
		_cancel_consumed_device_ids.erase(device_id)
		return true
	for row in _rows:
		if row.device.get_device_id() == device_id and row.confirmed:
			row.set_confirmed(false)
			_cancel_consumed_device_ids.append(device_id)
			changed.emit()
			return true
	return false


func _process(_delta: float) -> void:
	for row in _rows:
		row.device.poll()
		if (
			needs_confirmation
			and row.lane != Lane.UNASSIGNED
			and not row.confirmed
			and row.device.is_accept_just_pressed()
		):
			row.set_confirmed(true, true)
			changed.emit()
		var direction: Vector2 = row.device.get_direction()
		if row.latched:
			row.latched = direction.length() >= direction_release
			continue
		if absf(direction.x) >= direction_trigger and absf(direction.x) >= absf(direction.y):
			_move_row(row, int(signf(direction.x)))
			row.latched = true
		elif absf(direction.y) >= direction_trigger:
			if row.lane != Lane.UNASSIGNED and not row.confirmed:
				# Up asks for the previous character in the list.
				character_step_requested.emit(row.lane, -int(signf(direction.y)))
			row.latched = true


## Rebuilds the rows from the connected devices, keeping known devices in their lanes.
func _rebuild_rows() -> void:
	var previous_lanes: Dictionary[int, Lane] = {}
	for row in _rows:
		previous_lanes[row.device.get_device_id()] = row.lane
		row.queue_free()
	_rows.clear()
	for device_id in InputDevice.get_connected_device_ids():
		var row: DeviceRow = device_row_scene.instantiate()
		_device_rows.add_child(row)
		row.show_device(InputDevice.create(device_id), _last_lane() + 1)
		var lane: Lane = mini(previous_lanes.get(device_id, Lane.UNASSIGNED), _last_lane()) as Lane
		row.place(lane, lane_colors[lane])
		_rows.append(row)
	changed.emit()


## Moves a device one lane left (step -1) or right (step 1). A side holds one device.
func _move_row(row: DeviceRow, step: int) -> void:
	var target: Lane = clampi(row.lane + step, Lane.PLAYER1, _last_lane()) as Lane
	if target == row.lane or (target != Lane.UNASSIGNED and _lane_row(target)):
		return
	row.place(target, lane_colors[target])
	row.set_confirmed(false)
	changed.emit()


## Rightmost lane: the lanes end at the middle with one player.
func _last_lane() -> Lane:
	return Lane.UNASSIGNED if one_player else Lane.PLAYER2


func _lane_row(lane: Lane) -> DeviceRow:
	for row in _rows:
		if row.lane == lane:
			return row
	return null


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_rebuild_rows()
