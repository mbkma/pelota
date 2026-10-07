## Debug drawing of the ball trajectory, the players' movement targets and the AI's angle
## bisector positioning.
class_name TrajectoryDrawer
extends MeshInstance3D

## Height (m) above the ground at which movement and bisector lines are drawn
const LINE_HEIGHT := Vector3(0, 1, 0)
## Length (m) of the drawn angle bisector
const BISECTOR_LENGTH: float = 24.0

@export var trajectory_color: Color = Color(1, 0, 0)
## Color of the movement arrows
@export var arrow_color: Color = Color(0, 1, 0)
## Size of the arrowheads (m)
@export var arrow_size: float = 0.3
## Color of the lines to the ends of the service line
@export var bisector_line_color: Color = Color(0.942, 0.882, 0.342, 1.0)
## Color of the angle bisector
@export var bisector_angle_color: Color = Color(0.904, 0.809, 0.149, 1.0)
@export var match_manager: MatchManager

var _material := StandardMaterial3D.new()
## Line vertices and their colors of the current frame
var _vertices := PackedVector3Array()
var _colors := PackedColorArray()


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true


func _process(_delta: float) -> void:
	mesh.clear_surfaces()
	if not is_visible_in_tree():
		return

	_vertices.clear()
	_colors.clear()
	var ball: Ball = match_manager.ball
	if ball:
		for i in range(1, ball.trajectory.size()):
			_add_line(ball.trajectory[i - 1].point, ball.trajectory[i].point, trajectory_color)

	for player: Player in [match_manager.player0, match_manager.player1]:
		var target: Variant = player.get_movement_target()
		if target != null:
			_add_arrow(player.position + LINE_HEIGHT, target + LINE_HEIGHT)
		if player.bisector_direction != Vector3.ZERO:
			_add_angle_bisector(player)
	if _vertices.is_empty():
		return

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for i in _vertices.size():
		mesh.surface_set_color(_colors[i])
		mesh.surface_add_vertex(_vertices[i])
	mesh.surface_end()


func _add_arrow(start_pos: Vector3, end_pos: Vector3) -> void:
	_add_line(start_pos, end_pos, arrow_color)
	var direction: Vector3 = (end_pos - start_pos).normalized()
	if direction == Vector3.ZERO:
		return
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	var up: Vector3 = direction.cross(right).normalized()
	var base: Vector3 = end_pos - direction * arrow_size - up * arrow_size * 0.5
	_add_line(end_pos, base + right * arrow_size * 0.5, arrow_color)
	_add_line(end_pos, base - right * arrow_size * 0.5, arrow_color)


## Lines from where the opponent hits to both ends of the service line and their bisector.
func _add_angle_bisector(player: Player) -> void:
	var origin: Vector3 = player.opponent_hit_position + LINE_HEIGHT
	_add_line(origin, player.bisector_service_line_left + LINE_HEIGHT, bisector_line_color)
	_add_line(origin, player.bisector_service_line_right + LINE_HEIGHT, bisector_line_color)
	_add_line(origin, origin + player.bisector_direction * BISECTOR_LENGTH, bisector_angle_color)


func _add_line(start_pos: Vector3, end_pos: Vector3, color: Color) -> void:
	_vertices.append_array([start_pos, end_pos])
	_colors.append_array([color, color])
