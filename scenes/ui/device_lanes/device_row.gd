## A connected input device in the device lanes (see DeviceLanes): its card (icon and name, and
## once its side confirmed a ready badge) sits in the slot of the lane the device is in.
class_name DeviceRow
extends HBoxContainer

@export var keyboard_icon: Texture2D
@export var gamepad_icon: Texture2D
## Seconds the ready badge takes to pop in
@export var ready_pop_time: float = 0.3

var device: InputDevice
var lane: DeviceLanes.Lane = DeviceLanes.Lane.UNASSIGNED
## Whether the player on this device's side has confirmed
var confirmed: bool = false
## Set after a step until the direction returns to neutral; set at first so a direction held
## while plugging in does not move the device.
var latched: bool = true

@onready var _card: Control = %Card
@onready var _icon: TextureRect = %Icon
@onready var _ready_badge: TextureRect = %ReadyBadge
@onready var _name_label: Label = %NameLabel
@onready var _ready_label: Label = %ReadyLabel


func show_device(input_device: InputDevice, lane_count: int) -> void:
	device = input_device
	_icon.texture = keyboard_icon if device is KeyboardInput else gamepad_icon
	_name_label.text = device.get_display_name()
	for slot_lane in get_child_count():
		get_child(slot_lane).visible = slot_lane < lane_count
	set_confirmed(false)


## Moves the card into the slot of `new_lane`, its icon in `color`.
func place(new_lane: DeviceLanes.Lane, color: Color) -> void:
	lane = new_lane
	_card.reparent(get_child(lane), false)
	_icon.modulate = color


## Shows the ready badge and label while `value`; `pop` lets the badge pop in.
func set_confirmed(value: bool, pop: bool = false) -> void:
	confirmed = value
	_ready_badge.visible = value
	# Keep the label's space so the card does not jump when it appears.
	_ready_label.modulate.a = 1.0 if value else 0.0
	if value and pop:
		_ready_badge.scale = Vector2.ZERO
		(
			_ready_badge
			. create_tween()
			. tween_property(_ready_badge, ^"scale", Vector2.ONE, ready_pop_time)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
