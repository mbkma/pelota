## Builds the umpire chair as at the US Open (UMPIRE_CHAIR_PATH): a navy stand on a platform,
## climbed by steps at the back, with Polo panels on its sides, the seat box with Chubb panels,
## a footrest, a small desk with a microphone and a screen, and a navy sunshade on white poles.
## It faces +Z (the court) and stands on y = 0. Run it after changing it:
##
##     godot --headless --path . -s res://scenes/match/umpire/umpire_chair_builder.gd
class_name UmpireChairBuilder
extends SceneTree

const UMPIRE_CHAIR_PATH: String = "res://scenes/match/umpire/umpire_chair.tscn"
const MESH_PATH: String = "res://scenes/match/umpire/umpire_chair.res"
const MATERIAL_FOLDER: String = "res://scenes/match/umpire/materials/"
## Height (m) of the seat, and half the stand's width (x) and depth (z)
const SEAT_HEIGHT: float = 1.85
const HALF_SIZE: Vector2 = Vector2(0.42, 0.42)


func _initialize() -> void:
	_build()


func _build() -> void:
	# Let the project's autoloads start up first: quitting before they have does not end the run.
	for frame in 10:
		await process_frame
	var materials: Dictionary[String, Material] = MaterialLibrary.load_folder(MATERIAL_FOLDER)
	var navy: Material = materials["navy"]
	var white: Material = materials["white"]
	var black: Material = materials["black"]
	var cushion: Material = materials["cushion"]
	var screen: Material = materials["screen"]
	var logos: Material = UsOpenLogos.MATERIAL
	var geometry := FlatGeometry.new()

	# Platform and the steps up the back
	geometry.box(navy, Transform3D(Basis(), Vector3(0.0, 0.08, 0.05)), Vector3(1.25, 0.16, 1.45))
	for step in 4:
		var height: float = 0.16 + (step + 1) * 0.3
		var z: float = -HALF_SIZE.y - 0.2 + step * 0.22
		geometry.box(
			navy, Transform3D(Basis(), Vector3(0.0, height - 0.025, z)), Vector3(0.6, 0.05, 0.26)
		)
	for side: float in [-0.32, 0.32]:
		geometry.beam(
			navy,
			Vector3(side, 0.16, -HALF_SIZE.y - 0.4),
			Vector3(side, SEAT_HEIGHT - 0.3, -HALF_SIZE.y + 0.1),
			0.05
		)
	# Four legs with braces, and the Polo panels on the sides
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var foot := Vector3(corner.x * HALF_SIZE.x, 0.16, corner.y * HALF_SIZE.y)
		geometry.beam(navy, foot, Vector3(foot.x, SEAT_HEIGHT - 0.25, foot.z), 0.07)
	for side: float in [-1.0, 1.0]:
		var x: float = side * HALF_SIZE.x
		geometry.beam(navy, Vector3(x, 0.5, -HALF_SIZE.y), Vector3(x, 1.2, HALF_SIZE.y), 0.04)
		geometry.box(
			navy,
			Transform3D(Basis(), Vector3(x + side * 0.03, 0.62, 0.0)),
			Vector3(0.03, 0.42, 0.8)
		)
		UsOpenLogos.add(
			geometry,
			logos,
			&"polo",
			Vector3(x + side * 0.05, 0.62, 0.0),
			Vector3(side, 0.0, 0.0),
			0.2
		)
	# Footrest in front of the seat
	geometry.box(
		navy,
		Transform3D(Basis(), Vector3(0.0, SEAT_HEIGHT - 0.55, HALF_SIZE.y + 0.12)),
		Vector3(0.75, 0.05, 0.4)
	)
	geometry.beam(
		navy,
		Vector3(-0.3, SEAT_HEIGHT - 0.55, HALF_SIZE.y + 0.3),
		Vector3(-0.3, SEAT_HEIGHT - 0.25, HALF_SIZE.y),
		0.04
	)
	geometry.beam(
		navy,
		Vector3(0.3, SEAT_HEIGHT - 0.55, HALF_SIZE.y + 0.3),
		Vector3(0.3, SEAT_HEIGHT - 0.25, HALF_SIZE.y),
		0.04
	)
	# Seat box with the Chubb panels, the cushion and the backrest
	var seat := Vector3(0.0, SEAT_HEIGHT - 0.15, -0.05)
	geometry.box(navy, Transform3D(Basis(), seat), Vector3(0.9, 0.3, 0.85))
	for side: float in [-1.0, 1.0]:
		UsOpenLogos.add(
			geometry,
			logos,
			&"chubb",
			seat + Vector3(side * 0.451, 0.0, 0.0),
			Vector3(side, 0.0, 0.0),
			0.12
		)
	geometry.box(
		cushion, Transform3D(Basis(), seat + Vector3(0.0, 0.19, 0.0)), Vector3(0.55, 0.08, 0.5)
	)
	geometry.box(
		navy,
		Transform3D(Basis(Vector3.RIGHT, -0.12), seat + Vector3(0.0, 0.55, -0.37)),
		Vector3(0.6, 0.65, 0.08)
	)
	# Armrests, the desk in front with its screen and the microphone
	for side: float in [-0.38, 0.38]:
		geometry.box(
			navy, Transform3D(Basis(), seat + Vector3(side, 0.35, 0.0)), Vector3(0.1, 0.3, 0.7)
		)
	var desk := seat + Vector3(0.0, 0.42, 0.42)
	geometry.box(white, Transform3D(Basis(Vector3.RIGHT, 0.25), desk), Vector3(0.85, 0.04, 0.3))
	geometry.box(
		screen,
		Transform3D(Basis(Vector3.RIGHT, -0.5), desk + Vector3(0.22, 0.08, 0.02)),
		Vector3(0.24, 0.16, 0.02)
	)
	geometry.beam(
		black, desk + Vector3(-0.15, 0.02, 0.05), desk + Vector3(-0.12, 0.25, -0.05), 0.012
	)
	geometry.box(
		black, Transform3D(Basis(), desk + Vector3(-0.12, 0.27, -0.06)), Vector3(0.05, 0.05, 0.07)
	)
	# Sunshade on two white poles
	var shade_height: float = SEAT_HEIGHT + 1.45
	for side: float in [-0.4, 0.4]:
		geometry.beam(
			white, seat + Vector3(side, 0.1, -0.4), Vector3(side, shade_height, -0.35), 0.03
		)
	var shade := Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.0, shade_height + 0.03, 0.05))
	geometry.box(navy, shade, Vector3(1.05, 0.04, 1.0))
	UsOpenLogos.add_flat(
		geometry, logos, &"us_open", shade * Vector3(0.0, 0.021, 0.0), Vector3.BACK, 0.25
	)

	var mesh: ArrayMesh = geometry.to_mesh()
	ResourceSaver.save(mesh, MESH_PATH, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(MESH_PATH)
	var chair := MeshInstance3D.new()
	chair.name = "UmpireChair"
	chair.mesh = mesh
	var scene := PackedScene.new()
	scene.pack(chair)
	ResourceSaver.save(scene, UMPIRE_CHAIR_PATH)
	chair.free()
	quit()
