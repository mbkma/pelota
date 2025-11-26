## Manages dynamic splitscreen mode for two human players
class_name SplitscreenManager
extends Control

## Splitscreen modes
enum SplitscreenMode { NORMAL, VERTICAL_SPLIT, HORIZONTAL_SPLIT }

## Signal emitted when splitscreen mode is toggled
signal splitscreen_toggled(enabled: bool)

@export var cameras: MatchCameras
@export var player0: Player
@export var player1: Player

## UI nodes for splitscreen display
@onready var hbox_container: HBoxContainer = $HBoxContainer
@onready var vbox_container: VBoxContainer = $VBoxContainer
@onready var left_viewport: SubViewport = $HBoxContainer/LeftViewportContainer/LeftViewport
@onready var right_viewport: SubViewport = $HBoxContainer/RightViewportContainer/RightViewport
@onready var top_viewport: SubViewport = $VBoxContainer/TopViewportContainer/TopViewport
@onready var bottom_viewport: SubViewport = $VBoxContainer/BottomViewportContainer/BottomViewport

## Cameras for each viewport
var left_camera: Camera3D
var right_camera: Camera3D
var top_camera: Camera3D
var bottom_camera: Camera3D

## Original world camera reference
var _original_camera: Camera3D

## State tracking
var current_mode: SplitscreenMode = SplitscreenMode.NORMAL


func _ready() -> void:
	# Verify required exports
	if not cameras or not player0 or not player1:
		push_error("SplitscreenManager missing required exports!")
		return

	# Hide splitscreen UI initially
	hbox_container.hide()
	vbox_container.hide()

	# Check if both players are human-controlled
	if not _are_both_players_human():
		Loggie.msg("[Splitscreen] Disabled: not all players are human").debug()
		return

	# Create cameras for all viewports
	_create_viewport_cameras()

	# Start in normal mode
	current_mode = SplitscreenMode.NORMAL


func _input(event: InputEvent) -> void:
	# Toggle splitscreen with 'X' key
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		toggle_splitscreen()
		get_tree().root.set_input_as_handled()


## Create dedicated cameras for each viewport (children of each SubViewport)
func _create_viewport_cameras() -> void:
	# Create left camera for horizontal split
	left_camera = Camera3D.new()
	left_camera.name = "LeftCamera"
	left_viewport.add_child(left_camera)

	# Create right camera for horizontal split
	right_camera = Camera3D.new()
	right_camera.name = "RightCamera"
	right_viewport.add_child(right_camera)

	# Create top camera for vertical split
	top_camera = Camera3D.new()
	top_camera.name = "TopCamera"
	top_viewport.add_child(top_camera)

	# Create bottom camera for vertical split
	bottom_camera = Camera3D.new()
	bottom_camera.name = "BottomCamera"
	bottom_viewport.add_child(bottom_camera)

	Loggie.msg("[Splitscreen] Cameras created").debug()


## Cycle through splitscreen modes
func toggle_splitscreen() -> void:
	match current_mode:
		SplitscreenMode.NORMAL:
			_enable_vertical_splitscreen()
		SplitscreenMode.VERTICAL_SPLIT:
			_enable_horizontal_splitscreen()
		SplitscreenMode.HORIZONTAL_SPLIT:
			_disable_splitscreen()


## Enable vertical splitscreen (side-by-side)
func _enable_vertical_splitscreen() -> void:
	if not _are_both_players_human():
		push_error("Cannot enable splitscreen: not all players are human")
		return

	if not left_camera or not right_camera:
		push_error("Viewport cameras not initialized")
		return

	# Store and disable the original broadcast camera
	_original_camera = get_viewport().get_camera_3d()
	if _original_camera:
		_original_camera.current = false

	# Setup and activate cameras
	_update_camera_from_player(left_camera, player0)
	left_camera.make_current()

	_update_camera_from_player(right_camera, player1)
	right_camera.make_current()

	# Hide any other splitscreen containers
	vbox_container.hide()

	# Show vertical split UI
	hbox_container.show()

	# Set up camera following
	_start_camera_following()

	current_mode = SplitscreenMode.VERTICAL_SPLIT
	splitscreen_toggled.emit(true)
	Loggie.msg("[Splitscreen] Vertical enabled - Press X for horizontal").debug()


## Enable horizontal splitscreen (top-bottom)
func _enable_horizontal_splitscreen() -> void:
	if not _are_both_players_human():
		push_error("Cannot enable splitscreen: not all players are human")
		return

	if not top_camera or not bottom_camera:
		push_error("Viewport cameras not initialized")
		return

	# Store and disable the original broadcast camera if not already done
	if current_mode == SplitscreenMode.NORMAL:
		_original_camera = get_viewport().get_camera_3d()
		if _original_camera:
			_original_camera.current = false

	# Setup and activate cameras
	_update_camera_from_player(top_camera, player0)
	top_camera.make_current()

	_update_camera_from_player(bottom_camera, player1)
	bottom_camera.make_current()

	# Hide any other splitscreen containers
	hbox_container.hide()

	# Show horizontal split UI
	vbox_container.show()

	# Set up camera following (if not already running)
	if current_mode == SplitscreenMode.NORMAL:
		_start_camera_following()

	current_mode = SplitscreenMode.HORIZONTAL_SPLIT
	splitscreen_toggled.emit(true)
	Loggie.msg("[Splitscreen] Horizontal enabled - Press X to return to normal").debug()


## Disable splitscreen mode
func _disable_splitscreen() -> void:
	# Stop camera following
	_stop_camera_following()

	# Hide all splitscreen UI
	hbox_container.hide()
	vbox_container.hide()

	# Re-enable the original broadcast camera
	if _original_camera:
		_original_camera.make_current()

	current_mode = SplitscreenMode.NORMAL
	splitscreen_toggled.emit(false)
	Loggie.msg("[Splitscreen] Disabled - Press X to enable").debug()


## Update a viewport camera to match a player's camera
func _update_camera_from_player(viewport_cam: Camera3D, player: Player) -> void:
	if not player or not player.camera:
		return

	viewport_cam.global_position = player.camera.global_position
	viewport_cam.global_rotation = player.camera.global_rotation
	viewport_cam.fov = player.camera.fov


## Start following players with viewport cameras
func _start_camera_following() -> void:
	set_process(true)


## Stop following players with viewport cameras
func _stop_camera_following() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	# Continuously sync viewport cameras with player cameras
	match current_mode:
		SplitscreenMode.VERTICAL_SPLIT:
			_update_camera_from_player(left_camera, player0)
			_update_camera_from_player(right_camera, player1)
		SplitscreenMode.HORIZONTAL_SPLIT:
			_update_camera_from_player(top_camera, player0)
			_update_camera_from_player(bottom_camera, player1)
		_:
			pass


## Check if both players are controlled by humans
func _are_both_players_human() -> bool:
	if not _is_player_human(player0):
		return false
	if not _is_player_human(player1):
		return false
	return true


## Check if a single player is human-controlled
func _is_player_human(player: Player) -> bool:
	if not player or not player.controller:
		return false

	var controller_script = player.controller.get_script()
	if not controller_script:
		return false

	var script_path = controller_script.resource_path
	return "human_controller" in script_path.to_lower()
