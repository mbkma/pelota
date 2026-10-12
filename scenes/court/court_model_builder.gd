## Builds the look of the court as at the US Open (COURT_MODEL_PATH): the blue hard court with
## its lines, the singles net between posts inside the doubles alleys (no singles sticks), with
## its white tape, center strap and Cadillac crests, and the slogan painted on the surround. It
## is only the look: the court's regions and the net's collision are in the court scene, and
## the ball's flight over the net is computed by the ball, whose cord height the net follows
## (Ball.net_height). Run it after changing it:
##
##     godot --headless --path . -s res://scenes/court/court_model_builder.gd
class_name CourtModelBuilder
extends SceneTree

const COURT_MODEL_PATH: String = "res://scenes/court/court_model.tscn"
const MESH_PATH: String = "res://scenes/court/court_model.res"
const NET_SHADER: Shader = preload("res://scenes/court/net.gdshader")

## Half size (m) of the doubles court (x) and of its length (z), and the singles court's half
## width, to the lines' outer edges
const DOUBLES_HALF_WIDTH: float = 5.485
const HALF_LENGTH: float = 11.885
const SINGLES_HALF_WIDTH: float = 4.115
## Service lines' distance from the net, and the lines' widths (baselines are wider)
const SERVICE_LINE: float = 6.4
const LINE_WIDTH: float = 0.05
const BASELINE_WIDTH: float = 0.1
const CENTER_MARK_LENGTH: float = 0.1
## Net posts: x of their middle and height (see Ball.NET_HALF_WIDTH and NET_POST_HEIGHT)
const POST: Vector2 = Vector2(Ball.NET_HALF_WIDTH, Ball.NET_POST_HEIGHT)
## Height of the white tape over the cord, and the net's thickness
const TAPE_HEIGHT: float = 0.065
const NET_HALF_THICKNESS: float = 0.012
## The color of the court, a soft blue
const COURT_COLOR: Color = Color(0.125, 0.195, 0.375)
## Segments the net's sagging top is made of
const NET_SEGMENTS: int = 48

var _materials: Dictionary[String, Material] = {}


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var court := _material("court", COURT_COLOR, 0.75)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.3
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.93, 0.93, 0.93))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	texture.color_ramp = ramp
	court.albedo_texture = texture
	court.uv1_triplanar = true
	court.uv1_world_triplanar = true
	_material("line", Color(0.95, 0.95, 0.94), 0.6)
	_material("post", Color(0.05, 0.08, 0.22), 0.45, 0.4)
	_material("white", Color(0.94, 0.94, 0.92), 0.5)
	var net := ShaderMaterial.new()
	net.resource_name = "net"
	net.shader = NET_SHADER
	_materials["net"] = net
	_materials["logos"] = UsOpenLogos.make_material()
	_materials["logos_cut_out"] = UsOpenLogos.make_material(true)

	var geometry := FlatGeometry.new()
	_build_surface(geometry)
	_build_net(geometry)

	var mesh: ArrayMesh = geometry.to_mesh()
	ResourceSaver.save(mesh, MESH_PATH, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(MESH_PATH)
	var model := MeshInstance3D.new()
	model.name = "CourtModel"
	model.mesh = mesh
	var scene := PackedScene.new()
	scene.pack(model)
	ResourceSaver.save(scene, COURT_MODEL_PATH)
	model.free()
	quit()


## The blue court, its lines, and the slogan painted on the green beside the near half.
func _build_surface(geometry: FlatGeometry) -> void:
	_rectangle(
		geometry,
		"court",
		Vector2(-DOUBLES_HALF_WIDTH, -HALF_LENGTH),
		Vector2(DOUBLES_HALF_WIDTH, HALF_LENGTH),
		0.0
	)
	var lines: Array[Rect2] = []
	for side: float in [-1.0, 1.0]:
		# Baselines and center marks, service lines, sidelines
		lines.append(
			_span(
				-DOUBLES_HALF_WIDTH,
				DOUBLES_HALF_WIDTH,
				side * HALF_LENGTH,
				side * (HALF_LENGTH - BASELINE_WIDTH)
			)
		)
		lines.append(
			_span(
				-LINE_WIDTH * 0.5,
				LINE_WIDTH * 0.5,
				side * (HALF_LENGTH - BASELINE_WIDTH),
				side * (HALF_LENGTH - BASELINE_WIDTH - CENTER_MARK_LENGTH)
			)
		)
		lines.append(
			_span(
				-SINGLES_HALF_WIDTH,
				SINGLES_HALF_WIDTH,
				side * (SERVICE_LINE - LINE_WIDTH * 0.5),
				side * (SERVICE_LINE + LINE_WIDTH * 0.5)
			)
		)
		for half_width: float in [DOUBLES_HALF_WIDTH, SINGLES_HALF_WIDTH]:
			lines.append(
				_span(
					side * half_width, side * (half_width - LINE_WIDTH), -HALF_LENGTH, HALF_LENGTH
				)
			)
	lines.append(
		_span(
			-LINE_WIDTH * 0.5,
			LINE_WIDTH * 0.5,
			-SERVICE_LINE - LINE_WIDTH * 0.5,
			SERVICE_LINE + LINE_WIDTH * 0.5
		)
	)
	for line in lines:
		_rectangle(geometry, "line", line.position, line.end, 0.002)
	UsOpenLogos.add_flat(
		geometry,
		_materials["logos"],
		&"healthiest_sport",
		Vector3(8.6, 0.003, 4.2),
		Vector3.FORWARD,
		1.25,
		Color(1.0, 1.0, 1.0, 0.85)
	)


## The net: posts, the mesh with its white tape over the sagging cord, the
## center strap, the bands along its ends and foot, and a Cadillac crest near each end.
func _build_net(geometry: FlatGeometry) -> void:
	var half: float = NET_HALF_THICKNESS
	for side: float in [-1.0, 1.0]:
		var post := Vector3(side * POST.x, 0.0, 0.0)
		geometry.box(
			_materials["post"],
			Transform3D(Basis(), post + Vector3.UP * POST.y * 0.5),
			Vector3(0.1, POST.y, 0.1)
		)
		geometry.box(
			_materials["post"],
			Transform3D(Basis(), post + Vector3.UP * (POST.y + 0.015)),
			Vector3(0.12, 0.03, 0.12)
		)
		geometry.box(
			_materials["post"],
			Transform3D(Basis(), post + Vector3(side * 0.08, 0.85, 0.0)),
			Vector3(0.07, 0.12, 0.08)
		)
		# Dark band along the net's end at the post
		var end: float = side * (POST.x - 0.07)
		geometry.box(
			_materials["post"],
			Transform3D(Basis(), Vector3(end, _cord(end) * 0.5, 0.0)),
			Vector3(0.05, _cord(end), half * 2.2)
		)
		for face: float in [-1.0, 1.0]:
			UsOpenLogos.add(
				geometry,
				_materials["logos_cut_out"],
				&"cadillac_crest",
				Vector3(side * 4.55, 0.66, face * (half + 0.004)),
				Vector3(0.0, 0.0, face),
				0.3
			)
	for i in NET_SEGMENTS:
		var x0: float = lerpf(-POST.x + 0.05, POST.x - 0.05, float(i) / NET_SEGMENTS)
		var x1: float = lerpf(-POST.x + 0.05, POST.x - 0.05, float(i + 1) / NET_SEGMENTS)
		var top0: float = _cord(x0)
		var top1: float = _cord(x1)
		# Mesh, both sides showing (the shader draws both faces)
		geometry.quad(
			_materials["net"],
			Vector3(x0, 0.0, 0.0),
			Vector3(x1, 0.0, 0.0),
			Vector3(x1, top1 - TAPE_HEIGHT, 0.0),
			Vector3(x0, top0 - TAPE_HEIGHT, 0.0),
			Vector3.BACK,
			Color.WHITE,
			PackedVector2Array(
				[
					Vector2(x0, 0.0),
					Vector2(x1, 0.0),
					Vector2(x1, top1 - TAPE_HEIGHT),
					Vector2(x0, top0 - TAPE_HEIGHT)
				]
			)
		)
		# Tape over the cord, and a band along the net's foot
		for face: float in [-1.0, 1.0]:
			geometry.quad(
				_materials["white"],
				Vector3(x0, top0 - TAPE_HEIGHT, face * half),
				Vector3(x1, top1 - TAPE_HEIGHT, face * half),
				Vector3(x1, top1, face * half),
				Vector3(x0, top0, face * half),
				Vector3(0.0, 0.0, face)
			)
			geometry.quad(
				_materials["post"],
				Vector3(x0, 0.0, face * half * 0.5),
				Vector3(x1, 0.0, face * half * 0.5),
				Vector3(x1, 0.045, face * half * 0.5),
				Vector3(x0, 0.045, face * half * 0.5),
				Vector3(0.0, 0.0, face)
			)
		geometry.quad(
			_materials["white"],
			Vector3(x0, top0, -half),
			Vector3(x1, top1, -half),
			Vector3(x1, top1, half),
			Vector3(x0, top0, half),
			Vector3.UP
		)
	# Center strap holding the cord down
	geometry.box(
		_materials["white"],
		Transform3D(Basis(), Vector3(0.0, Ball.NET_CENTER_HEIGHT * 0.5, 0.0)),
		Vector3(0.05, Ball.NET_CENTER_HEIGHT, half * 2.4)
	)


## Height of the net's top at `x`, where the ball meets the cord.
func _cord(x: float) -> float:
	return Ball.net_height(x)


## A flat rectangle on the ground from `from` to `to` (x, z) at `height`.
func _rectangle(
	geometry: FlatGeometry, material: String, from: Vector2, to: Vector2, height: float
) -> void:
	geometry.quad(
		_materials[material],
		Vector3(from.x, height, from.y),
		Vector3(to.x, height, from.y),
		Vector3(to.x, height, to.y),
		Vector3(from.x, height, to.y),
		Vector3.UP
	)


## The rectangle between x `x0` and `x1` and z `z0` and `z1`, in any order.
func _span(x0: float, x1: float, z0: float, z1: float) -> Rect2:
	var from := Vector2(minf(x0, x1), minf(z0, z1))
	return Rect2(from, Vector2(maxf(x0, x1), maxf(z0, z1)) - from)


func _material(
	material_name: String, color: Color, roughness: float, metallic: float = 0.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.vertex_color_use_as_albedo = true
	_materials[material_name] = material
	return material
