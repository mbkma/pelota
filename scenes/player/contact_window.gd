## Stretch of the incoming ball's flight after it bounces on a player's side in which a
## groundstroke can meet it. The player decides how early to take the ball: early on the rise (at
## EARLY_HEIGHT), the standard contact as the ball drops to STANDARD_HEIGHT after the apex (at the
## apex of a lower bounce), or late as it drops to LATE_HEIGHT. A player only moves back a little
## for a groundstroke, so the window ends where it would have to move back farther: a deep ball
## is taken earlier and higher. The earliness of a contact is 1 at the early end, STANDARD at the
## standard contact and 0 at the late end; the window keeps the ball's distance from the net at
## these points, which stays the same while the ball flies.
class_name ContactWindow
extends RefCounted

## Ball heights (m) of the early end (rising), the standard contact and the late end (dropping)
const EARLY_HEIGHT: float = 0.8
const STANDARD_HEIGHT: float = 1.1
const LATE_HEIGHT: float = 0.5
## Earliness of the standard contact
const STANDARD: float = 0.5

## Distance from the net (m) of the ball at the early end, the standard contact and the late end
var early_depth: float
var standard_depth: float
var late_depth: float
var _side: float


## Window of `trajectory` on the court side `side` (sign of z), ending before the first step
## for which `within_retreat` (TrajectoryStep -> bool) is false; null if the ball does not bounce
## on that side.
static func create(
	trajectory: Array[TrajectoryStep], side: float, within_retreat: Callable
) -> ContactWindow:
	var bounced: Array[TrajectoryStep] = []
	for step in trajectory:
		if step.bounces > 1:
			break
		if step.bounces != 1 or signf(step.point.z) != side:
			continue
		if not bounced.is_empty() and not within_retreat.call(step):
			break
		bounced.append(step)
	if bounced.is_empty():
		return null

	var apex: int = 0
	for i in bounced.size():
		if bounced[i].point.y > bounced[apex].point.y:
			apex = i
	var early: int = apex
	for i in apex:
		if bounced[i].point.y >= EARLY_HEIGHT:
			early = i
			break
	var standard: int = apex
	for i in range(apex, bounced.size()):
		if bounced[i].point.y <= STANDARD_HEIGHT:
			standard = i
			break
	var late: int = bounced.size() - 1
	for i in range(standard, bounced.size()):
		if bounced[i].point.y <= LATE_HEIGHT:
			late = i
			break

	var window := ContactWindow.new()
	window._side = side
	window.early_depth = absf(bounced[early].point.z)
	window.standard_depth = absf(bounced[standard].point.z)
	window.late_depth = absf(bounced[late].point.z)
	return window


## Steps of `trajectory` inside the window, from the early to the late end.
func steps_in(trajectory: Array[TrajectoryStep]) -> Array[TrajectoryStep]:
	var steps: Array[TrajectoryStep] = []
	for step in trajectory:
		if step.bounces > 1:
			break
		var depth: float = absf(step.point.z)
		if step.bounces == 1 and signf(step.point.z) == _side and depth >= early_depth:
			if depth > late_depth:
				break
			steps.append(step)
	return steps


## Earliness in [0, 1] of meeting the ball at `step`.
func earliness_of(step: TrajectoryStep) -> float:
	var depth: float = absf(step.point.z)
	if depth <= standard_depth:
		if standard_depth <= early_depth:
			return STANDARD
		return lerpf(
			1.0, STANDARD, clampf(inverse_lerp(early_depth, standard_depth, depth), 0.0, 1.0)
		)
	if late_depth <= standard_depth:
		return STANDARD
	return lerpf(STANDARD, 0.0, clampf(inverse_lerp(standard_depth, late_depth, depth), 0.0, 1.0))


## Share in [0, 1] by which `earliness` is earlier than the standard contact (1 at the early end).
static func early_share(earliness: float) -> float:
	return clampf(inverse_lerp(STANDARD, 1.0, earliness), 0.0, 1.0)


## Share in [0, 1] by which `earliness` is later than the standard contact (1 at the late end).
static func late_share(earliness: float) -> float:
	return clampf(inverse_lerp(STANDARD, 0.0, earliness), 0.0, 1.0)


## Distance from the net (m) of the ball when met at `earliness`.
func depth_at(earliness: float) -> float:
	if earliness >= STANDARD:
		return lerpf(standard_depth, early_depth, inverse_lerp(STANDARD, 1.0, earliness))
	return lerpf(late_depth, standard_depth, inverse_lerp(0.0, STANDARD, earliness))
