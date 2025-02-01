extends Panel

@onready var animation_player := $AnimationPlayer
@onready var timer := $Timer


func _ready() -> void:
	animation_player.play("fade_in")
	timer.start(5)
	timer.connect("timeout",Callable(self,"on_timer_timeout"))


func initialize(song):
	$Label.text = "song.title" + " by " + "song.artist"


func on_timer_timeout():
	animation_player.play("fade_out")
