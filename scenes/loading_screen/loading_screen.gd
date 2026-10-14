## The loading screen, with a random tip about the game under the progress bar. A long load
## shows another tip every TIP_DURATION seconds; a tip is never shown twice in a row.
extends LoadingScreen

## Seconds a tip stays before the next one, when loading takes that long
const TIP_DURATION: float = 8.0
## Controls are named for the keyboard first, then for the gamepad: "Space / A" (see KeyboardInput
## and GamepadInput).
const TIPS: PackedStringArray = [
	"Watch the match from the broadcast, elevated, courtside or overhead camera, or through your player's eyes: set the camera view in the pause menu or in the interface options.",
	"Hold a shot button to build power, and release it just before the racket meets the ball.",
	"The circle on your opponent's side shows where the ball can land: the better your timing, the smaller it gets.",
	"A gold landing circle means a perfect shot, with extra pace and spin.",
	"Your aim stays where you leave it: steer it with the direction while the ball comes towards you.",
	"Get to the blue ring early: once you press a shot button, your player only shuffles slowly towards the ball.",
	"Balls met off the racket's sweet spot lose pace and accuracy.",
	"Three shots: topspin with Space / A, slice with Shift / X and the drop shot with Ctrl / Y.",
	"Serve flat (Space / A) for pace, slice (Shift / X) for a curving serve or kick (Ctrl / Y) for a safe, high-bouncing serve.",
	"To serve, release the button to toss the ball and press it again right before contact: the closer to contact, the faster and more precise the serve.",
	"Before serving, slide along the baseline with left and right to change your angle.",
	"Close to the net, a ball you take before it bounces is volleyed automatically.",
	"At the net, the drop shot button (Ctrl / Y) plays a drop volley that dies right behind the net.",
	"Move forward after a strong shot to finish the point - but watch out for passing shots and lobs.",
	"Break points and set points add pressure, which lowers precision. Calmer players cope better.",
	"Running drains stamina, which costs speed and accuracy. Keep an eye on the panels in the corners.",
	"Long rallies make the crowd go wild.",
	"The match statistics are in the pause menu (Esc / Start).",
	"Playing with a friend? Press X during the match to switch between one view, side by side and top and bottom split screen.",
	"In the player selection, move your keyboard or controller left or right to take a player. A player without one is played by the CPU.",
	"In training, press E or the right trigger for the next ball from the ball machine.",
	"On the tournament draw, the shoulder buttons (Page Up / Page Down) switch between the rounds of the draw.",
	"Choose best of 3 or best of 5 sets for your tournament matches on the draw.",
	"In the options, the shoulder buttons (Page Up / Page Down) switch between the tabs.",
	"Game running slowly? Lower the Crowd Count or the Crowd Detail in the graphics options.",
	"Gamepad vibration can be turned off in the input options.",
]

## Index in TIPS of the tip shown last, also by an earlier loading screen
static var _last_tip: int = -1

@onready var _tip_label: Label = %TipLabel


func _ready() -> void:
	_show_next_tip()
	var timer := Timer.new()
	timer.wait_time = TIP_DURATION
	timer.autostart = true
	timer.timeout.connect(_show_next_tip)
	add_child(timer)


func _show_next_tip() -> void:
	if _last_tip < 0:
		_last_tip = randi() % TIPS.size()
	# Any tip but the last one
	var tip: int = randi() % (TIPS.size() - 1)
	if tip >= _last_tip:
		tip += 1
	_last_tip = tip
	_tip_label.text = TIPS[tip]
