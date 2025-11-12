class_name TrajectoryDrawer
extends MeshInstance3D

@export var trajectory_color: Color = Color(1, 0, 0)  # Color for the trajectory line
@export var arrow_color: Color = Color(0, 1, 0)  # Color for AI movement arrows (green)
@export var arrow_size: float = 0.3  # Size of arrowhead
@export var bisector_line_color: Color = Color(0.942, 0.882, 0.342, 1.0)  # Color for lines to corners (bright orange)
@export var bisector_angle_color: Color = Color(0.904, 0.809, 0.149, 1.0)  # Color for angle bisector (dark orange)
@export var ball: Ball
@export var players: Array[Player] = []  # Store player references to visualize their movement paths


var trajectory_material := ORMMaterial3D.new()
var arrow_material := ORMMaterial3D.new()
var bisector_material := ORMMaterial3D.new()


func set_active_ball(b):
	ball = b

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	mesh.clear_surfaces()

	if ball and ball.trajectory and ball.trajectory.size() > 1:
		draw_trajectory(ball.trajectory)

	# Draw AI movement arrows from player paths
	for player in players:
		if player and player._path.size() > 0:
			# Draw from current position to first waypoint
			draw_arrow(player.position + Vector3(0,1,0), player._path[0] + Vector3(0,1,0))

			# Draw between consecutive waypoints
			for i in range(player._path.size() - 1):
				draw_arrow(player._path[i] + Vector3(0,1,0), player._path[i + 1] + Vector3(0,1,0))

		# Draw angle bisector visualization for each player
		if player and player.bisector_direction != Vector3.ZERO:
			draw_angle_bisector_visualization(player)


# Function to draw the trajectory using ImmediateMesh
func draw_trajectory(trajectory: Array) -> void:
	# Begin drawing the trajectory
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, trajectory_material)
	trajectory_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trajectory_material.albedo_color = trajectory_color

	for step in trajectory:
		mesh.surface_add_vertex(step.point)

	# End drawing the trajectory
	mesh.surface_end()


# Draw an arrow from start_pos to end_pos
func draw_arrow(start_pos: Vector3, end_pos: Vector3) -> void:
	var direction: Vector3 = (end_pos - start_pos).normalized()
	var distance: float = start_pos.distance_to(end_pos)

	# Draw the arrow line
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, arrow_material)
	arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_material.albedo_color = arrow_color

	mesh.surface_add_vertex(start_pos)
	mesh.surface_add_vertex(end_pos)

	mesh.surface_end()

	# Draw arrowhead (two lines forming a V shape)
	if distance > 0:
		var arrowhead_base: Vector3 = end_pos - direction * arrow_size
		var right: Vector3 = direction.cross(Vector3.UP).normalized()
		var up: Vector3 = direction.cross(right).normalized()

		var arrowhead_point1: Vector3 = arrowhead_base + (right * arrow_size * 0.5) - (up * arrow_size * 0.5)
		var arrowhead_point2: Vector3 = arrowhead_base - (right * arrow_size * 0.5) - (up * arrow_size * 0.5)

		# Draw arrowhead lines
		mesh.surface_begin(Mesh.PRIMITIVE_LINES, arrow_material)
		arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arrow_material.albedo_color = arrow_color

		mesh.surface_add_vertex(end_pos)
		mesh.surface_add_vertex(arrowhead_point1)

		mesh.surface_end()

		mesh.surface_begin(Mesh.PRIMITIVE_LINES, arrow_material)
		arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arrow_material.albedo_color = arrow_color

		mesh.surface_add_vertex(end_pos)
		mesh.surface_add_vertex(arrowhead_point2)

		mesh.surface_end()


# Draw angle bisector visualization using pre-calculated data from player
func draw_angle_bisector_visualization(player: Player) -> void:
	if not player.opponent:
		return

	var service_line_left: Vector3 = player.bisector_service_line_left
	var service_line_right: Vector3 = player.bisector_service_line_right
	var bisector_direction: Vector3 = player.bisector_direction
	var opponent_xz: Vector3 = player.opponent_hit_position


	# Draw lines to service line extremes in bright orange
	draw_line(opponent_xz + Vector3(0, 1, 0), service_line_left + Vector3(0, 1, 0), bisector_line_color)
	draw_line(opponent_xz + Vector3(0, 1, 0), service_line_right + Vector3(0, 1, 0), bisector_line_color)

	# Draw bisector line extending from opponent position using pre-calculated direction
	var bisector_end: Vector3 = opponent_xz + bisector_direction * 24.0
	draw_line(opponent_xz + Vector3(0, 1, 0), bisector_end + Vector3(0, 1, 0), bisector_angle_color)


# Draw a simple line between two points
func draw_line(start_pos: Vector3, end_pos: Vector3, color: Color) -> void:
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, bisector_material)
	bisector_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bisector_material.albedo_color = color

	mesh.surface_add_vertex(start_pos)
	mesh.surface_add_vertex(end_pos)

	mesh.surface_end()
