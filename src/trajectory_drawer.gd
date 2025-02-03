extends MeshInstance3D

@export var trajectory_color: Color = Color(1, 0, 0)  # Color for the trajectory line
@export var ball: Ball

var material := ORMMaterial3D.new()


func set_active_ball(b):
	ball = b


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if ball and ball.trajectory:
		draw_trajectory(ball.trajectory)


# Function to draw the trajectory using ImmediateMesh
func draw_trajectory(trajectory: Array) -> void:
	mesh.clear_surfaces()

	# Begin drawing the trajectory
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = trajectory_color

	for point in trajectory:
		mesh.surface_add_vertex(point)

	# End drawing the trajectory
	mesh.surface_end()
