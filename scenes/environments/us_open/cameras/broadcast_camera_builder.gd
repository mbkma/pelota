## Builds the broadcast camera scene (BROADCAST_CAMERA_PATH) from primitive meshes: a TV camera
## at court level as at the US Open, low on a tripod, wrapped in a boxy blue rain cover with only
## the lens hood, the viewfinder and the pan bars showing. It looks along -Z and stands on
## y = 0. Run it after changing it:
##
##     godot --headless --path . \
##         -s res://scenes/environments/us_open/cameras/broadcast_camera_builder.gd
class_name BroadcastCameraBuilder
extends SceneTree

const BROADCAST_CAMERA_PATH: String = (
	"res://scenes/environments/us_open/cameras/broadcast_camera.tscn"
)
const MATERIAL_FOLDER: String = "res://scenes/environments/us_open/cameras/materials/"
## Height (m) of the lens axis
const LENS_HEIGHT: float = 0.95
## Front of the rain cover (z, m), and the lens's glass radius (lens_glass.tres's glass_radius)
const COVER_FRONT: float = -0.46
const GLASS_RADIUS: float = 0.072

var _root: Node3D


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	_root = Node3D.new()
	_root.name = "BroadcastCamera"
	var materials: Dictionary[String, Material] = MaterialLibrary.load_folder(MATERIAL_FOLDER)
	var steel: Material = materials["steel"]
	var rubber: Material = materials["rubber"]
	var cover: Material = materials["cover"]
	var strap: Material = materials["strap"]
	var black: Material = materials["black"]
	var tally: Material = materials["tally"]
	var screen: Material = materials["screen"]
	var glass: Material = materials["lens_glass"]

	# Tripod: three splayed legs with a spreader, and the fluid head
	var head := Vector3(0.0, LENS_HEIGHT - 0.3, 0.05)
	for i in 3:
		var foot: Vector3 = Basis(Vector3.UP, i * TAU / 3.0) * Vector3(0.0, 0.0, 0.42)
		_beam("Leg%d" % i, head, foot + Vector3(0.0, 0.0, 0.05), 0.035, steel)
		_beam(
			"Spreader%d" % i,
			Vector3(0.0, 0.12, 0.05),
			foot * 0.55 + Vector3(0.0, 0.12, 0.05),
			0.02,
			steel
		)
		_box(
			"Foot%d" % i,
			Vector3(0.06, 0.03, 0.08),
			Transform3D(Basis(), foot + Vector3(0.0, 0.015, 0.05)),
			rubber
		)
	_box(
		"Head",
		Vector3(0.18, 0.12, 0.22),
		Transform3D(Basis(), head + Vector3(0.0, 0.08, 0.0)),
		steel
	)
	# Pan bars reaching back to the operator, with grips
	for side: float in [-1.0, 1.0]:
		var start: Vector3 = head + Vector3(side * 0.08, 0.1, 0.08)
		var end: Vector3 = start + Vector3(side * 0.18, -0.12, 0.55)
		_beam("PanBar%s" % ("L" if side < 0.0 else "R"), start, end, 0.022, steel)
		_beam("Grip%s" % ("L" if side < 0.0 else "R"), end.lerp(start, 0.25), end, 0.04, rubber)

	# Rain cover over the body and lens: a box with softened edges, two straps and a top flap
	var middle := Vector3(0.0, LENS_HEIGHT, -0.02)
	var length: float = 0.88
	_box("Cover", Vector3(0.34, 0.3, length), Transform3D(Basis(), middle), cover)
	_box("CoverSides", Vector3(0.3, 0.36, length - 0.02), Transform3D(Basis(), middle), cover)
	_box(
		"CoverFlap",
		Vector3(0.36, 0.025, 0.5),
		Transform3D(Basis(), middle + Vector3(0.0, 0.18, 0.12)),
		cover
	)
	for z: float in [-0.22, 0.2]:
		_box(
			"Strap%d" % int(z * 100.0),
			Vector3(0.355, 0.375, 0.035),
			Transform3D(Basis(), middle + Vector3(0.0, 0.0, z)),
			strap
		)
	_box(
		"TallyFront",
		Vector3(0.04, 0.018, 0.02),
		Transform3D(Basis(), Vector3(0.1, LENS_HEIGHT + 0.19, COVER_FRONT + 0.06)),
		tally
	)

	# Viewfinder sticking out at the back, its hood and screen
	var viewfinder := Vector3(0.0, LENS_HEIGHT + 0.2, 0.47)
	_box("Viewfinder", Vector3(0.22, 0.15, 0.12), Transform3D(Basis(), viewfinder), black)
	_box(
		"ViewfinderHood",
		Vector3(0.2, 0.13, 0.1),
		Transform3D(Basis(), viewfinder + Vector3(0.0, 0.0, 0.1)),
		rubber
	)
	_box(
		"ViewfinderScreen",
		Vector3(0.17, 0.1, 0.004),
		Transform3D(Basis(), viewfinder + Vector3(0.0, 0.0, 0.151)),
		screen
	)
	_box(
		"TallyViewfinder",
		Vector3(0.03, 0.014, 0.01),
		Transform3D(Basis(), viewfinder + Vector3(0.07, 0.085, -0.03)),
		tally
	)

	# Lens front out of the cover: housing, hood and glass
	_cylinder("LensFront", 0.088, 0.085, 0.08, Vector3(0.0, LENS_HEIGHT, COVER_FRONT - 0.04), black)
	var hood := CylinderMesh.new()
	hood.top_radius = 0.115
	hood.bottom_radius = 0.092
	hood.height = 0.13
	hood.radial_segments = 32
	hood.rings = 1
	hood.cap_top = false
	_part("Hood", hood, rubber, _along_z(Vector3(0.0, LENS_HEIGHT, COVER_FRONT - 0.145)))
	var inside := CylinderMesh.new()
	inside.top_radius = 0.108
	inside.bottom_radius = 0.085
	inside.height = 0.128
	inside.radial_segments = 32
	inside.rings = 1
	inside.cap_top = false
	inside.flip_faces = true
	_part(
		"HoodInside",
		inside,
		materials["hood_inside"],
		_along_z(Vector3(0.0, LENS_HEIGHT, COVER_FRONT - 0.145))
	)
	var dome := SphereMesh.new()
	dome.radius = GLASS_RADIUS
	dome.height = GLASS_RADIUS * 2.0
	dome.radial_segments = 48
	dome.rings = 24
	_part(
		"FrontGlass",
		dome,
		glass,
		Transform3D(
			Basis(Vector3.RIGHT, -PI * 0.5).scaled_local(Vector3(1.0, 0.28, 1.0)),
			Vector3(0.0, LENS_HEIGHT, COVER_FRONT - 0.085)
		)
	)

	var scene := PackedScene.new()
	scene.pack(_root)
	ResourceSaver.save(scene, BROADCAST_CAMERA_PATH)
	_root.free()
	quit()


func _part(part_name: String, mesh: PrimitiveMesh, material: Material, place: Transform3D) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	mesh.material = material
	part.mesh = mesh
	part.transform = place
	_root.add_child(part)
	part.owner = _root


func _box(part_name: String, size: Vector3, place: Transform3D, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	_part(part_name, box, material, place)


## A cylinder along the lens axis (its top towards -Z).
func _cylinder(
	part_name: String, top: float, bottom: float, height: float, center: Vector3, material: Material
) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 32
	cylinder.rings = 1
	_part(part_name, cylinder, material, _along_z(center))


## A thin round bar from `from` to `to`.
func _beam(
	part_name: String, from: Vector3, to: Vector3, radius: float, material: Material
) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = from.distance_to(to)
	cylinder.radial_segments = 10
	cylinder.rings = 1
	var y: Vector3 = (to - from).normalized()
	var x: Vector3 = y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y)
	_part(part_name, cylinder, material, Transform3D(Basis(x, y, z), (from + to) * 0.5))


## A cylinder's placement turned to lie along the lens axis, its top towards -Z.
func _along_z(center: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), center)
