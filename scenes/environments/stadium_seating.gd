class_name StadiumSeating
extends Resource
## The seats of a stadium in sections. The stadium draws its seats from them (see StadiumSeats)
## and the crowd sits its spectators on them. Each seat is its position on the floor below the
## middle of the seat (x, y, z) and the angle (w, radians around the vertical) turning +Z, the
## way it faces, towards the court.

@export var sections: Array[PackedVector4Array] = []
## Where the photographers and TV camera operators at court level sit (they do not cheer)
@export var photographers := PackedVector4Array()


static func seat_transform(seat: Vector4) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, seat.w), Vector3(seat.x, seat.y, seat.z))
