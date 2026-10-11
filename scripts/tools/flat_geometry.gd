class_name FlatGeometry
extends RefCounted
## Collects flat-shaded triangles per material and turns them into a mesh.

var _tools: Dictionary[Material, SurfaceTool] = {}


## A flat convex polygon (points in order around it, either way round) facing `facing`.
func polygon(
	material: Material,
	points: PackedVector3Array,
	facing: Vector3,
	color: Color = Color.WHITE,
	uvs: PackedVector2Array = PackedVector2Array()
) -> void:
	var normal: Vector3 = (points[2] - points[0]).cross(points[1] - points[0])
	if normal.length_squared() < 1e-10:
		normal = facing
	if normal.dot(facing) < 0.0:
		points.reverse()
		uvs.reverse()
		normal = -normal
	normal = normal.normalized()
	var tool: SurfaceTool = _tool(material)
	for i in range(1, points.size() - 1):
		for corner: int in [0, i, i + 1]:
			tool.set_normal(normal)
			tool.set_color(color)
			if not uvs.is_empty():
				tool.set_uv(uvs[corner])
			tool.add_vertex(points[corner])


func quad(
	material: Material,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	facing: Vector3,
	color: Color = Color.WHITE,
	uvs: PackedVector2Array = PackedVector2Array()
) -> void:
	polygon(material, PackedVector3Array([a, b, c, d]), facing, color, uvs)


## A box of `size` placed by `place` (its center and orientation).
func box(material: Material, place: Transform3D, size: Vector3, color: Color = Color.WHITE) -> void:
	var half: Vector3 = size * 0.5
	for axis in 3:
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for side: float in [-1.0, 1.0]:
			var points := PackedVector3Array()
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var local := Vector3()
				local[axis] = side * half[axis]
				local[u] = corner.x * half[u]
				local[v] = corner.y * half[v]
				points.append(place * local)
			var facing := Vector3()
			facing[axis] = side
			polygon(material, points, place.basis * facing, color)


## A square beam `width` thick from `from` to `to`.
func beam(
	material: Material, from: Vector3, to: Vector3, width: float, color: Color = Color.WHITE
) -> void:
	var along: Vector3 = to - from
	var z: Vector3 = along.normalized()
	var up: Vector3 = Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x: Vector3 = up.cross(z).normalized()
	var y: Vector3 = z.cross(x)
	box(
		material,
		Transform3D(Basis(x, y, z), (from + to) * 0.5),
		Vector3(width, width, along.length()),
		color
	)


## A wall `thickness` thick from `from` to `to` (both at its foot), `height` high.
func wall(
	material: Material,
	from: Vector3,
	to: Vector3,
	thickness: float,
	height: float,
	color: Color = Color.WHITE
) -> void:
	var z: Vector3 = (to - from).normalized()
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	var center: Vector3 = (from + to) * 0.5 + Vector3.UP * height * 0.5
	box(
		material,
		Transform3D(Basis(x, Vector3.UP, z), center),
		Vector3(thickness, height, (to - from).length()),
		color
	)


func is_empty() -> bool:
	return _tools.is_empty()


func to_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material: Material in _tools:
		_tools[material].commit(mesh)
	return mesh


func _tool(material: Material) -> SurfaceTool:
	if not _tools.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		_tools[material] = tool
	return _tools[material]
