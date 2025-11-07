extends Panel

@onready var animation_player := $AnimationPlayer
@onready var timer := $Timer
@onready var label: Label = $HBoxContainer/Label
@onready var texture_rect: TextureRect = $HBoxContainer/TextureRect


func _ready() -> void:
	GlobalMusicPlayer.track_started.connect(_on_track_started)


func _on_track_started(track: Track):
	set_track(track)
	animation_player.play("fade_in")
	await get_tree().create_timer(20).timeout
	animation_player.play("fade_out")


func set_track(track: Track):
	label.text = track.title + " by " + track.artist
	texture_rect.texture = load(track.cover_path)
