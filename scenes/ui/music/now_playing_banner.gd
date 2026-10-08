## Banner announcing the song that just started: slides in with the cover, title and artist,
## stays a few seconds and slides out again.
class_name NowPlayingBanner
extends PanelContainer

const SLIDE_IN_TIME: float = 0.6
const SHOW_TIME: float = 6.0
const SLIDE_OUT_TIME: float = 0.5
## Distance (px) from the right screen edge while shown, and from the bottom edge (kept clear
## for bottom-wide buttons in menus)
const MARGIN: float = 32.0
const BOTTOM_MARGIN: float = 96.0

var _tween: Tween
var _time: float = 0.0

@onready var _cover: TextureRect = %Cover
@onready var _title_label: Label = %TitleLabel
@onready var _artist_label: Label = %ArtistLabel
@onready var _equalizer_bars: Array[Node] = %Equalizer.get_children()


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	# Small equalizer animation next to "NOW PLAYING".
	_time += delta
	for i in _equalizer_bars.size():
		var bar: Control = _equalizer_bars[i]
		bar.scale.y = 0.35 + 0.65 * absf(sin(_time * (5.0 + i * 1.7) + i))


func announce(track: MusicTrack) -> void:
	_cover.texture = track.cover
	_title_label.text = track.title
	_artist_label.text = track.artist
	_artist_label.visible = not track.artist.is_empty()
	visible = true
	reset_size()

	var viewport_size: Vector2 = get_viewport_rect().size
	var shown_x: float = viewport_size.x - size.x - MARGIN
	var hidden_x: float = viewport_size.x + 20.0
	position = Vector2(hidden_x, viewport_size.y - size.y - BOTTOM_MARGIN)
	modulate.a = 0.0

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	(
		_tween
		. tween_property(self, "position:x", shown_x, SLIDE_IN_TIME)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.tween_property(self, "modulate:a", 1.0, SLIDE_IN_TIME * 0.6)
	_tween.chain().tween_interval(SHOW_TIME)
	(
		_tween
		. chain()
		. tween_property(self, "position:x", hidden_x, SLIDE_OUT_TIME)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	_tween.chain().tween_callback(hide)
