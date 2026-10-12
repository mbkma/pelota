class_name StadiumShape
extends RefCounted
## The polygon a stadium's stands run around: the field's rectangle with rounded corners, each
## corner made of straight facets. Everything in the bowl is placed by its offset from it (how
## far out from the field wall, called d), so it follows the bowl as it widens. Vertices and
## edges are numbered around the polygon; edge i runs from vertex i to vertex i + 1.

## Facets per corner
var corner_facets: int
## Outward normal and direction of each edge (x, z)
var normals := PackedVector2Array()
var directions := PackedVector2Array()

## Vertices at offset 0, and how each moves per meter of offset (its miter)
var _vertices := PackedVector2Array()
var _miters := PackedVector2Array()
var _rng := RandomNumberGenerator.new()


## The polygon around a field of `field_half_size` (x, z) centered at `center` (x, z), with
## corners of `corner_radius`. `shade_seed` seeds the variation of the surfaces' gray levels.
func _init(
	center: Vector2, field_half_size: Vector2, corner_radius: float, facets: int, shade_seed: int
) -> void:
	corner_facets = facets
	_rng.seed = shade_seed
	var inner: Vector2 = field_half_size - Vector2.ONE * corner_radius
	var centers: Array[Vector2] = [
		center + Vector2(inner.x, inner.y),
		center + Vector2(-inner.x, inner.y),
		center + Vector2(-inner.x, -inner.y),
		center + Vector2(inner.x, -inner.y)
	]
	for corner in 4:
		for step in facets + 1:
			var angle: float = deg_to_rad(corner * 90.0 + step * 90.0 / facets)
			_vertices.append(centers[corner] + Vector2(cos(angle), sin(angle)) * corner_radius)
	var count: int = _vertices.size()
	for i in count:
		var along: Vector2 = _vertices[(i + 1) % count] - _vertices[i]
		var normal := Vector2(along.y, -along.x).normalized()
		if normal.dot(_vertices[i] + along * 0.5 - center) < 0.0:
			normal = -normal
		normals.append(normal)
		directions.append(along.normalized())
	for i in count:
		var before: Vector2 = normals[(i - 1 + count) % count]
		var after: Vector2 = normals[i]
		_miters.append((before + after) / (1.0 + before.dot(after)))


func edge_count() -> int:
	return _vertices.size()


## Point of vertex `vertex` at offset `d` (x, z).
func at(vertex: int, d: float) -> Vector2:
	var i: int = posmod(vertex, edge_count())
	return _vertices[i] + _miters[i] * d


func point(vertex: int, d: float, height: float) -> Vector3:
	var p: Vector2 = at(vertex, d)
	return Vector3(p.x, height, p.y)


## Point at `t` (0 to 1) along `edge` at offset `d` (x, z).
func on_edge(edge: int, t: float, d: float) -> Vector2:
	return at(edge, d).lerp(at(edge + 1, d), t)


func edge_length(edge: int, d: float) -> float:
	return at(edge, d).distance_to(at(edge + 1, d))


func outward(edge: int) -> Vector3:
	var n: Vector2 = normals[posmod(edge, edge_count())]
	return Vector3(n.x, 0.0, n.y)


## Which corner facet `edge` is (0 to corner_facets - 1), or corner_facets for a straight side.
## For a vertex, the facet starting at it.
func facet(edge: int) -> int:
	return posmod(edge, edge_count()) % (corner_facets + 1)


func is_side(edge: int) -> bool:
	return facet(edge) == corner_facets


## Whether `edge` is one of the long sides along the court (not an end behind a baseline)
func is_long_side(edge: int) -> bool:
	return is_side(edge) and absf(normals[posmod(edge, edge_count())].x) > 0.5


## A wall along the whole polygon at offset `d`, facing in (towards the field) or out.
func ring_wall(
	geometry: FlatGeometry,
	material: Material,
	d: float,
	bottom: float,
	top: float,
	inward: bool,
	shading: float = 0.04
) -> void:
	for edge in edge_count():
		var a: Vector2 = at(edge, d)
		var b: Vector2 = at(edge + 1, d)
		geometry.quad(
			material,
			Vector3(a.x, bottom, a.y),
			Vector3(b.x, bottom, b.y),
			Vector3(b.x, top, b.y),
			Vector3(a.x, top, a.y),
			-outward(edge) if inward else outward(edge),
			shade(shading)
		)


## A floor along the whole polygon from offset `from` to `to` at `height`.
func ring_floor(
	geometry: FlatGeometry,
	material: Material,
	from: float,
	to: float,
	height: float,
	up: bool = true,
	shading: float = 0.04
) -> void:
	ring_slope(geometry, material, Vector2(from, height), Vector2(to, height), up, shading)


## A surface along the whole polygon sloping from `from` to `to` (offset, height).
func ring_slope(
	geometry: FlatGeometry,
	material: Material,
	from: Vector2,
	to: Vector2,
	up: bool,
	shading: float = 0.04
) -> void:
	for edge in edge_count():
		geometry.quad(
			material,
			point(edge, from.x, from.y),
			point(edge + 1, from.x, from.y),
			point(edge + 1, to.x, to.y),
			point(edge, to.x, to.y),
			Vector3.UP if up else Vector3.DOWN,
			shade(shading)
		)


## Gray level varying around 1 by up to `amount`, so surfaces do not look flat.
func shade(amount: float) -> Color:
	var value: float = 1.0 + _rng.randf_range(-amount, amount)
	return Color(value, value, value)


## Rotation turning +Z to `direction` (x, z).
static func facing(direction: Vector2) -> Basis:
	return Basis(Vector3.UP, atan2(direction.x, direction.y))
