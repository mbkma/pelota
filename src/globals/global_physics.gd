extends Node

var DAMP := 0.7
var DEFAULT_GRAVITY := 10.0


func get_velocity_stroke_from_to(initial_pos: Vector3, destination_pos: Vector3, vz: float, spin: float, net_margin : float = 1.5) -> Vector3:
	var gravity := DEFAULT_GRAVITY+spin
	var vel := Vector3.ZERO
	var t = abs((destination_pos.z - initial_pos.z) / vz)
	assert(t>0)
	vel.x = (destination_pos.x-initial_pos.x)/t
	vel.y = (0.5*gravity*t*t-initial_pos.y)/t
	vel.z = vz

	return vel


func get_vy_with_net_margin(height, initial_pos, vz, spin: float):
	var gravity := DEFAULT_GRAVITY+spin
	# time at which ball is over net
	var t = abs(initial_pos.z / vz)
	assert(t>0)
	return (height-initial_pos.y+0.5*gravity*t*t)/t


#func ball_height_at_net(initial_pos, vel, spin: float):
#	var gravity := DEFAULT_GRAVITY+spin
#	var t = abs(initial_pos.z / vel.z)
#	return -0.5*gravity*t*t+vel.y*t+initial_pos.y


#func get_velocity_from_to(initial_pos, destination_pos, vy, spin: float) -> Vector3:
#	var gravity := DEFAULT_GRAVITY+spin
#	var vel := Vector3.ZERO
#	var t = (vy+sqrt(vy*vy + 2*gravity*(initial_pos.y-destination_pos.y))) / gravity
#	assert(t>0)
#	vel.x = (destination_pos.x-initial_pos.x)/t
#	vel.y = vy
#	vel.z = (destination_pos.z-initial_pos.z)/t
#
#	return vel


func get_ball_position_at_height_after_bounce(ball: Ball, height: float):
	var gravity := DEFAULT_GRAVITY
	var pred = get_ball_position_at_ground(ball)
	var pos1 = pred.pos
	var vel1 = pred.vel
	vel1 = _make_bounce(vel1)

	if vel1.y*vel1.y-2*gravity*height < 0:
		height = 0
		var t1 = (-vel1.y+sqrt(vel1.y*vel1.y-2*gravity*height)) / -gravity
		# pos where ball will be at time t
		pos1 = Vector3(0, -0.5 * DEFAULT_GRAVITY, 0) * t1 * t1 + vel1 * t1 + pos1
		return {"time": pred.time+t1, "pos": pos1}
	else:
		var t1: float = (-vel1.y+sqrt(vel1.y*vel1.y-2*gravity*height)) / -gravity
		# pos where ball will be at time t
		pos1 = Vector3(0, -0.5 * DEFAULT_GRAVITY, 0) * t1 * t1 + vel1 * t1 + pos1
		assert(abs(pos1.y - height) < 0.1)
		return {"time": pred.time+t1, "pos": pos1}


func get_ball_position_at(ball: Ball, posz: float) -> Dictionary:
	var gravity := DEFAULT_GRAVITY+ball.spin
	# time when ball will be at posz
	var t: float = (posz-ball.position.z) / ball.velocity.z

	# pos where ball will be at time t
	var pos = Vector3(0, -0.5 * gravity, 0) * t * t + ball.velocity * t + ball.position

	if pos.y < 0: # then the ball should have bounced
		var pred = get_ball_position_at_ground(ball)
		var pos1 = pred.pos
		var vel1 = pred.vel
		vel1 = _make_bounce(vel1)
		var t1: float = (posz-pos1.z) / vel1.z

		# pos where ball will be at time t
		pos1 = Vector3(0, -0.5 * DEFAULT_GRAVITY, 0) * t1 * t1 + vel1 * t1 + pos1
#		assert(abs(pos1.z-posz)<0.1 and pos1.y > 0)
		return {"time": pred.time+t1, "pos": pos1}
	else:
		assert(abs(pos.z-posz)<0.1 and pos.y > 0)
		return {"time": t, "pos": pos}


func get_ball_position_at_ground(ball: Ball):
	var gravity := DEFAULT_GRAVITY+ball.spin
	# first, compute the time when the ball will hit the ground
	var t2: float = (
		(-ball.velocity.y - sqrt(ball.velocity.y * ball.velocity.y + 2 * gravity * ball.position.y))
		/ -gravity
	)
	# then, compute where the ball will be at that time
	var pos2 = Vector3(0, -0.5 * gravity, 0) * t2 * t2 + ball.velocity * t2 + ball.position
	assert(abs(pos2.y) < 0.1)

	# finally, compute the ball.velocity BEFORE the ball hit the ground
	var vel = Vector3(0, -gravity, 0) * t2 + ball.velocity

	return {"time": t2, "pos": pos2, "vel": vel}


func _make_bounce(initial_vel):
	var vel = initial_vel.bounce(Vector3.UP)
	vel *= DAMP
#	vel.z *= 0.8
	return vel
