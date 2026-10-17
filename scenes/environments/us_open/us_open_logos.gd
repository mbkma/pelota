class_name UsOpenLogos
extends RefCounted
## The US Open's sponsor logos and markings in one texture atlas (sponsor_logos.png, white on
## transparent, drawn for the blue boards), and where each logo is in it.

const ATLAS: Texture2D = preload("res://scenes/environments/us_open/sponsor_logos.png")
## The materials the logos are drawn with: blended, or cut out (for logos in front of other
## see-through things, like the net, which blending would sort against)
const MATERIAL: Material = preload("res://scenes/environments/us_open/materials/logos.tres")
const MATERIAL_CUT_OUT: Material = preload(
	"res://scenes/environments/us_open/materials/logos_cut_out.tres"
)
## Rectangle of each logo in the atlas (UV)
const RECTS: Dictionary[StringName, Rect2] = {
	&"chase": Rect2(0.10107, 0.00391, 0.29785, 0.06055),
	&"us_open": Rect2(0.70020, 0.00391, 0.09961, 0.06055),
	&"us_open_finals": Rect2(0.21191, 0.07227, 0.07568, 0.06055),
	&"jp_morgan": Rect2(0.57861, 0.07227, 0.34277, 0.06055),
	&"emirates": Rect2(0.09229, 0.14062, 0.31543, 0.06055),
	&"american_express": Rect2(0.66455, 0.14062, 0.17041, 0.06055),
	&"usta": Rect2(0.15625, 0.20898, 0.18750, 0.06055),
	&"usopen_org": Rect2(0.50391, 0.21143, 0.49219, 0.05566),
	&"ibm": Rect2(0.16553, 0.27734, 0.16846, 0.06006),
	&"rolex": Rect2(0.67773, 0.27734, 0.14404, 0.06006),
	&"argenx": Rect2(0.15576, 0.34570, 0.18799, 0.06055),
	&"chubb": Rect2(0.58398, 0.34570, 0.33203, 0.06055),
	&"deloitte": Rect2(0.11572, 0.41406, 0.26855, 0.06055),
	&"fage": Rect2(0.64453, 0.41406, 0.21094, 0.06055),
	&"evian": Rect2(0.15820, 0.48242, 0.18359, 0.06006),
	&"wilson": Rect2(0.61523, 0.48242, 0.26953, 0.06055),
	&"polo": Rect2(0.12158, 0.55078, 0.25635, 0.06055),
	&"polo_ralph_lauren": Rect2(0.50391, 0.56543, 0.49219, 0.03125),
	&"espn": Rect2(0.15283, 0.61914, 0.19385, 0.06055),
	&"ticketmaster": Rect2(0.54150, 0.61914, 0.41699, 0.06055),
	&"cadillac": Rect2(0.01367, 0.68750, 0.47266, 0.06055),
	&"ihg": Rect2(0.60840, 0.68750, 0.28271, 0.06055),
	&"arthur_ashe_stadium": Rect2(0.00391, 0.77246, 0.49219, 0.02686),
	&"breaking_barriers": Rect2(0.50391, 0.77295, 0.49170, 0.02588),
	&"cadillac_crest": Rect2(0.19531, 0.82422, 0.10889, 0.06055),
	&"healthiest_sport": Rect2(0.66211, 0.82422, 0.17578, 0.06055),
	&"polo_pony": Rect2(0.21729, 0.89258, 0.06543, 0.06055),
}


## Width / height of `logo`.
static func aspect(logo: StringName) -> float:
	return RECTS[logo].size.x / RECTS[logo].size.y


## Adds `logo` to `geometry`, `height` m high, centered at `center` and facing `facing`
## (horizontal), tinted with `color`.
static func add(
	geometry: FlatGeometry,
	material: Material,
	logo: StringName,
	center: Vector3,
	facing: Vector3,
	height: float,
	color: Color = Color.WHITE
) -> void:
	var right: Vector3 = Vector3.UP.cross(facing).normalized() * height * aspect(logo) * 0.5
	var up: Vector3 = Vector3.UP * height * 0.5
	var rect: Rect2 = RECTS[logo]
	geometry.quad(
		material,
		center - right - up,
		center + right - up,
		center + right + up,
		center - right + up,
		facing,
		color,
		PackedVector2Array(
			[
				Vector2(rect.position.x, rect.end.y),
				Vector2(rect.end.x, rect.end.y),
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.position.x, rect.position.y)
			]
		)
	)


## Adds `logo` lying flat on the floor at `center`, `height` m deep, its top towards `up`.
static func add_flat(
	geometry: FlatGeometry,
	material: Material,
	logo: StringName,
	center: Vector3,
	up: Vector3,
	height: float,
	color: Color = Color.WHITE
) -> void:
	var along: Vector3 = up.normalized() * height * 0.5
	var right: Vector3 = up.normalized().cross(Vector3.UP) * height * aspect(logo) * 0.5
	var rect: Rect2 = RECTS[logo]
	geometry.quad(
		material,
		center - right - along,
		center + right - along,
		center + right + along,
		center - right + along,
		Vector3.UP,
		color,
		PackedVector2Array(
			[
				Vector2(rect.position.x, rect.end.y),
				Vector2(rect.end.x, rect.end.y),
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.position.x, rect.position.y)
			]
		)
	)
