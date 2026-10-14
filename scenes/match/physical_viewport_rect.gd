## Shows its SubViewport child, rendered at one pixel per screen pixel of the rect. The UI is
## scaled to the screen (see the stretch settings of the project), so a stretched
## SubViewportContainer would render at the UI's size and look blurry on a high-DPI screen. Like
## the container, it renders the viewport only while the rect is visible.
class_name PhysicalViewportRect
extends TextureRect

@onready var _viewport: SubViewport = get_child(0)


func _ready() -> void:
	texture = _viewport.get_texture()
	resized.connect(_fit_viewport)
	# The UI scale changes with the window size, also where the rect keeps its size.
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	_update_rendering()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _viewport != null:
		_update_rendering()


func _update_rendering() -> void:
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	)


func _fit_viewport() -> void:
	var to_pixels: Transform2D = (
		get_viewport().get_stretch_transform() * get_global_transform_with_canvas()
	)
	var pixels := Vector2i((size * to_pixels.get_scale()).round())
	# A rect not laid out yet (its container is hidden) shows nothing to render for.
	if pixels.x > 0 and pixels.y > 0:
		_viewport.size = pixels
