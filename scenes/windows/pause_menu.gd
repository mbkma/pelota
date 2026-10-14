@tool
class_name PauseMenu
extends OverlaidWindow

@export var options_menu_scene: PackedScene
## Path to a main menu scene.
## Will attempt to read from AppConfig if left empty.
@export_file("*.tscn") var main_menu_scene_path: String
@export_node_path(&"ConfirmationOverlaidWindow") var restart_confirmation_node_path: NodePath
@export_node_path(&"ConfirmationOverlaidWindow") var main_menu_confirmation_node_path: NodePath
@export_node_path(&"ConfirmationOverlaidWindow") var exit_confirmation_node_path: NodePath
@export var menu_container_node_path: NodePath = ^".."
## The match statistics shown by the Match Stats button; the button is hidden without them.
@export_node_path(&"MatchStatsPanel") var match_stats_panel_path: NodePath
## Whether the Controllers window can hand player 2 to a device (not in training, nor in a
## tournament, where the opponent is always the CPU)
@export var opponent_controllable: bool = true

var open_window: Node
## Releasing ui_cancel closes the menu or its window only after its press reached the menu: the
## press that closes an open dropdown list does not.
var _cancel_press := UiCancelPress.new()

@onready
var restart_confirmation: ConfirmationOverlaidWindow = get_node(restart_confirmation_node_path)
@onready
var main_menu_confirmation: ConfirmationOverlaidWindow = get_node(main_menu_confirmation_node_path)
@onready var exit_confirmation: ConfirmationOverlaidWindow = get_node(exit_confirmation_node_path)
@onready var menu_container: Node = get_node(menu_container_node_path)
@onready var options_button = %OptionsButton
@onready var match_stats_button = %MatchStatsButton
@onready var camera_view_control: ListOptionControl = %CameraViewControl
@onready var match_stats_panel: MatchStatsPanel = get_node_or_null(match_stats_panel_path)
@onready var main_menu_button = %MainMenuButton
@onready var controllers_window: ControllersWindow = %ControllersWindow
@onready var exit_button = %ExitButton


func get_main_menu_scene_path() -> String:
	if main_menu_scene_path.is_empty():
		return AppConfig.main_menu_scene_path
	return main_menu_scene_path


func close_window() -> void:
	if open_window != null:
		if open_window.has_method("close"):
			open_window.close()
		else:
			open_window.hide()
		open_window = null


func _disable_focus() -> void:
	for button in %MenuButtons.find_children("*", "BaseButton", true, false):
		button.focus_mode = FOCUS_NONE


func _enable_focus() -> void:
	for button in %MenuButtons.find_children("*", "BaseButton", true, false):
		button.focus_mode = FOCUS_ALL


func _load_scene(scene_path: String) -> void:
	_scene_tree.paused = false
	SceneLoader.load_scene(scene_path)


func _show_window(window: Control) -> void:
	_disable_focus.call_deferred()
	window.show()
	open_window = window
	await window.hidden
	open_window = null
	_enable_focus.call_deferred()


func _load_and_show_menu(scene: PackedScene) -> void:
	var window_instance: Control = scene.instantiate()
	window_instance.visible = false
	menu_container.add_child.call_deferred(window_instance)
	await _show_window(window_instance)
	window_instance.queue_free()


## Esc or the gamepad start button opens the menu, and closes it again when no sub window
## is open.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _cancel_press.is_unpaired_release(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause"):
		if not visible:
			show()
		elif open_window == null:
			close()
		get_viewport().set_input_as_handled()
		return
	# Esc is also ui_cancel: its release must not close the menu it just opened. With a sub
	# window open the release closes that window.
	if event.is_action_released(&"pause") and open_window == null:
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _handle_cancel_input() -> void:
	if open_window != null:
		close_window()
	else:
		super._handle_cancel_input()


func _refresh_exit_button() -> void:
	exit_button.visible = !OS.has_feature("web")


func _refresh_options_button() -> void:
	options_button.visible = options_menu_scene != null


func _refresh_main_menu_button() -> void:
	main_menu_button.visible = !get_main_menu_scene_path().is_empty()


func _refresh_camera_view() -> void:
	camera_view_control.value = UiSettings.get_camera_view()


## The statistics already showing (after a set or the match) need no button.
func _refresh_match_stats_button() -> void:
	match_stats_button.visible = match_stats_panel != null and not match_stats_panel.visible


func _ready() -> void:
	_refresh_exit_button()
	_refresh_options_button()
	_refresh_main_menu_button()
	_refresh_match_stats_button()
	visibility_changed.connect(_refresh_match_stats_button)
	restart_confirmation.confirmed.connect(_on_restart_confirmation_confirmed)
	main_menu_confirmation.confirmed.connect(_on_main_menu_confirmation_confirmed)
	exit_confirmation.confirmed.connect(_on_exit_confirmation_confirmed)
	if Engine.is_editor_hint():
		return
	# The camera view is also set in the options, which open from this menu.
	camera_view_control.setting_changed.connect(UiSettings.set_camera_view)
	UiSettings.changed.connect(_refresh_camera_view)
	_refresh_camera_view()


func _on_restart_button_pressed() -> void:
	_show_window(restart_confirmation)


func _on_controllers_button_pressed() -> void:
	controllers_window.one_player = (not opponent_controllable or GlobalGameData.tournament != null)
	_show_window(controllers_window)


func _on_match_stats_button_pressed() -> void:
	match_stats_panel.show_over_pause_menu()
	await _show_window(match_stats_panel)
	# The statistics take no focus, so none returns on its own (after _enable_focus).
	match_stats_button.grab_focus.call_deferred()


func _on_options_button_pressed() -> void:
	_load_and_show_menu(options_menu_scene)


func _on_main_menu_button_pressed() -> void:
	_show_window(main_menu_confirmation)


func _on_exit_button_pressed() -> void:
	_show_window(exit_confirmation)


func _on_restart_confirmation_confirmed() -> void:
	SceneLoader.reload_current_scene()
	close()


func _on_main_menu_confirmation_confirmed():
	_load_scene(get_main_menu_scene_path())


func _on_exit_confirmation_confirmed():
	get_tree().quit()
