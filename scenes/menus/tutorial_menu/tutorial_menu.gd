## How-to-play screen: one tutorial page at a time with an illustration, the explanation and
## the keyboard and gamepad controls it is about. Left and right turn the pages.
class_name TutorialMenu
extends Control

const CONTROL_ICON_SIZE := Vector2(40, 40)
const DOT_ACTIVE_COLOR := Palette.AMBER
const DOT_INACTIVE_COLOR := Color(Palette.CREAM, 0.3)

@export var tutorial: Tutorial

var _page_index: int = 0

@onready var _page_title: Label = %PageTitle
@onready var _page_text: Label = %PageText
@onready var _page_image: TextureRect = %PageImage
@onready var _controls: VBoxContainer = %Controls
@onready var _dots: HBoxContainer = %Dots
@onready var _previous_button: Button = %PreviousButton
@onready var _next_button: Button = %NextButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_previous_button.pressed.connect(_turn.bind(-1))
	_next_button.pressed.connect(_on_next_pressed)
	_back_button.pressed.connect(queue_free)
	for _page in tutorial.pages:
		var dot := Label.new()
		dot.text = "●"
		_dots.add_child(dot)
	_show_page(0)
	_next_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_turn(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_turn(1)
		get_viewport().set_input_as_handled()


func _on_next_pressed() -> void:
	if _page_index == tutorial.pages.size() - 1:
		queue_free()
	else:
		_turn(1)


func _turn(step: int) -> void:
	_show_page(clampi(_page_index + step, 0, tutorial.pages.size() - 1))


func _show_page(index: int) -> void:
	_page_index = index
	var page: TutorialPage = tutorial.pages[index]
	_page_title.text = page.title
	_page_text.text = page.text
	_page_image.texture = page.image

	for child in _controls.get_children():
		child.queue_free()
	for control in page.controls:
		_controls.add_child(_control_row(control))

	for i in _dots.get_child_count():
		_dots.get_child(i).modulate = DOT_ACTIVE_COLOR if i == index else DOT_INACTIVE_COLOR
	_previous_button.disabled = index == 0
	_next_button.text = "Finish" if index == tutorial.pages.size() - 1 else "Next"


func _control_row(control: TutorialControl) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for icon in control.keyboard_icons:
		row.add_child(_icon(icon))
	if not control.gamepad_icons.is_empty():
		var separator := Label.new()
		separator.text = "/"
		separator.modulate = Color(1, 1, 1, 0.5)
		row.add_child(separator)
		for icon in control.gamepad_icons:
			row.add_child(_icon(icon))
	var description := Label.new()
	description.text = control.description
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_spacer())
	row.add_child(description)
	return row


func _icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = CONTROL_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	return spacer
