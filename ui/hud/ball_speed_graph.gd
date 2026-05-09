class_name BallSpeedGraph
extends Control

const GRAPH_PADDING: float = 8.0
const GRAPH_BACKGROUND_COLOR: Color = Color(0.04, 0.05, 0.06, 0.75)
const GRAPH_GRID_COLOR: Color = Color(1, 1, 1, 0.08)
const GRAPH_BORDER_COLOR: Color = Color(1, 1, 1, 0.18)
const GRAPH_LINE_COLOR: Color = Color(0.35, 0.92, 1.0, 1.0)
const GRAPH_FILL_COLOR: Color = Color(0.35, 0.92, 1.0, 0.16)
const GRAPH_LAST_POINT_COLOR: Color = Color(1, 1, 1, 0.95)

@export var history_capacity: int = 240

var _samples: Array[Vector2] = []


func clear() -> void:
	_samples.clear()
	queue_redraw()


func append_speed(speed: float, delta: float) -> void:
	var elapsed: float = 0.0
	if not _samples.is_empty():
		elapsed = _samples[_samples.size() - 1].x + maxf(delta, 0.0)

	_samples.append(Vector2(elapsed, maxf(speed, 0.0)))
	while _samples.size() > max(history_capacity, 2):
		_samples.pop_front()

	queue_redraw()


func _draw() -> void:
	var bounds: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(bounds, GRAPH_BACKGROUND_COLOR, true)
	draw_rect(bounds, GRAPH_BORDER_COLOR, false, 1.0)

	if _samples.size() < 2:
		return

	var min_x: float = _samples[0].x
	var max_x: float = _samples[_samples.size() - 1].x
	if max_x <= min_x:
		return

	var max_speed: float = 1.0
	for sample in _samples:
		max_speed = maxf(max_speed, sample.y)

	var inner_size: Vector2 = size - Vector2(GRAPH_PADDING * 2.0, GRAPH_PADDING * 2.0)
	if inner_size.x <= 0.0 or inner_size.y <= 0.0:
		return

	var inner_origin: Vector2 = Vector2(GRAPH_PADDING, GRAPH_PADDING)
	var grid_step_y: float = inner_size.y / 4.0
	for i in range(1, 5):
		var grid_y: float = inner_origin.y + grid_step_y * float(i)
		draw_line(
			Vector2(inner_origin.x, grid_y),
			Vector2(inner_origin.x + inner_size.x, grid_y),
			GRAPH_GRID_COLOR,
			1.0,
		)

	var polyline: PackedVector2Array = PackedVector2Array()
	var fill_polygon: PackedVector2Array = PackedVector2Array()
	fill_polygon.append(Vector2(inner_origin.x, inner_origin.y + inner_size.y))

	for sample in _samples:
		var x_pos: float = remap(sample.x, min_x, max_x, inner_origin.x, inner_origin.x + inner_size.x)
		var y_pos: float = remap(sample.y, 0.0, max_speed, inner_origin.y + inner_size.y, inner_origin.y)
		var point: Vector2 = Vector2(x_pos, y_pos)
		polyline.append(point)
		fill_polygon.append(point)

	fill_polygon.append(Vector2(inner_origin.x + inner_size.x, inner_origin.y + inner_size.y))
	draw_colored_polygon(fill_polygon, GRAPH_FILL_COLOR)
	draw_polyline(polyline, GRAPH_LINE_COLOR, 2.0, true)
	draw_circle(polyline[polyline.size() - 1], 3.5, GRAPH_LAST_POINT_COLOR)
