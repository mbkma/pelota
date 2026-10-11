## The score panel of the TV broadcast, as at the US Open 2025: one row per player on a deep blue
## panel with a glowing top edge (seed, name, country, the serve swoosh, the games of each set,
## yellow for the set's winner, and the points in a white box). It shows extra information the
## way the broadcast does:
## - a caption (e.g. "BREAK POINT #2") on a yellow tab that slides up from behind the panel;
## - a statistic: the scores wipe away while the panel widens, the statistic's values fade in
##   and its title rises on a tab with the IBM logo; then all of it reverses.
## Everything is laid out for a 1080 pixel high screen and scaled to the actual one.
class_name ScoreDisplay
extends Control

const DESIGN_HEIGHT: float = 1080.0
## Distance of the panel from the screen's left and bottom edges
const MARGIN: Vector2 = Vector2(105.0, 105.0)
const ROW_HEIGHT: float = 42.0
## Left edges of the seed and the name, and the gap before the country
const SEED_LEFT: float = 10.0
const NAME_LEFT: float = 44.0
const COUNTRY_GAP: float = 9.0
## Score columns: room for the serve swoosh, width of a games column, the points box (size and
## gap to the panel's right edge)
const SERVE_WIDTH: float = 66.0
const GAMES_WIDTH: float = 33.0
const POINTS_BOX: Vector2 = Vector2(44.0, 34.0)
const POINTS_RIGHT: float = 6.0
## Statistic columns: widths of the value and the percentage
const STATISTIC_WIDTHS: Vector2 = Vector2(150.0, 118.0)
## Caption tab: height, padding around its text, width of the IBM block
const TAB_HEIGHT: float = 32.0
const TAB_PADDING: float = 12.0
const IBM_WIDTH: float = 64.0
## Animation times (s)
const TAB_TIME: float = 0.25
const WIPE_TIME: float = 0.3
const FADE_TIME: float = 0.2
const INTRO_TIME: float = 0.45

const NAVY := Color(0.06, 0.07, 0.22)
const BORDER := Color(0.26, 0.3, 0.78)
const WHITE := Color(0.96, 0.96, 0.98)
const YELLOW := Color(0.97, 0.8, 0.24)
const GLOW := Color(0.45, 0.8, 1.0)

const BLACK_FONT: Font = preload("res://assets/fonts/Lato-Black.ttf")
const BOLD_FONT: Font = preload("res://assets/fonts/Lato-Bold.ttf")
const SWOOSH: Texture2D = preload("res://assets/textures/ui/hud/serve_swoosh.png")

## Width of the name column (fits both players) and of the scores
var _names_width: float = 300.0
var _scores_width: float = 0.0
## Shown width of the scores (the rest is wiped away), how far the panel is widened for a
## statistic (0 to 1), and how much of the panel is revealed (0 to 1, for its intro)
var _scores_shown: float = 0.0
var _statistic_open: float = 0.0
var _reveal: float = 1.0
## Height of the tab above the panel's top (0: hidden behind the panel)
var _tab_shown: float = 0.0
## Columns of games shown (completed sets, then the current set)
var _games_columns: int = 1

var _panel: Control
var _background: Panel
var _sheen: TextureRect
var _glow: TextureRect
var _separator: ColorRect
var _seeds: Array[Label] = []
var _names: Array[Label] = []
var _countries: Array[Label] = []
var _scores: Control
var _serve_icons: Array[TextureRect] = []
var _games: Array[Array] = [[], []]
var _point_boxes: Array[Panel] = []
var _points: Array[Label] = []
var _statistics: Control
var _statistic_values: Array[Array] = [[], []]
var _tab: Control
var _tab_ibm: ColorRect
var _tab_band: ColorRect
var _tab_label: Label
var _tween: Tween
## Timer hiding the shown caption or statistic
var _graphic_timer: SceneTreeTimer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()
	_set_games_columns(1)
	_scores_shown = _scores_width
	_layout()


## Shows the name, country and seed of `player_index`'s player.
func set_player(player_index: int, player_data: PlayerData) -> void:
	_seeds[player_index].text = str(player_data.rank)
	_names[player_index].text = player_data.last_name.to_upper()
	_countries[player_index].text = player_data.country_code
	var widest: float = 0.0
	for i in 2:
		widest = maxf(widest, _text_width(_names[i]) + COUNTRY_GAP + _text_width(_countries[i]))
	_names_width = NAME_LEFT + widest + 56.0
	_layout()


## Shows `score`. Points change at once, as on TV; when a set begins the panel widens.
func set_score(score: Score) -> void:
	var columns: int = score.completed_sets.size() + (0 if score.is_match_over() else 1)
	for player in 2:
		var labels: Array = _games[player]
		for i in labels.size():
			var label: Label = labels[i]
			if i < score.completed_sets.size():
				var games: Vector2i = score.completed_sets[i]
				label.text = str(games[player])
				var won: bool = games[player] > games[1 - player]
				label.add_theme_color_override("font_color", YELLOW if won else WHITE)
			elif i == score.completed_sets.size():
				label.text = str(score.games[player])
				label.add_theme_color_override("font_color", WHITE)
		_serve_icons[player].visible = score.current_server == player and not score.is_match_over()
		if score.is_tiebreak:
			_points[player].text = str(score.tiebreak_points[player])
		else:
			_points[player].text = _point_text(score.points[player])
		_point_boxes[player].visible = not score.is_match_over()
	if columns != _games_columns:
		var widen: bool = _scores_shown >= _scores_width
		_set_games_columns(columns)
		if widen:
			_new_tween().tween_method(_set_scores_shown, _scores_shown, _scores_width, WIPE_TIME)
	_layout()


## Wipes the panel in from its left edge, as at the start of the broadcast.
func play_intro() -> void:
	_reveal = 0.0
	_layout()
	(
		_new_tween()
		. tween_method(_set_reveal, 0.0, 1.0, INTRO_TIME)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


## Shows `text` on the yellow tab above the panel for `seconds`.
func show_caption(text: String, seconds: float) -> void:
	_hide_graphic_now()
	_set_tab(text, false)
	_tween_tab(_new_tween(), TAB_HEIGHT)
	_hide_after(seconds)


## Shows the statistic `title` for `seconds`: per player its value and percentage (or "").
func show_statistic(title: String, values: Array[PackedStringArray], seconds: float) -> void:
	_hide_graphic_now()
	for player in 2:
		for column in 2:
			(_statistic_values[player][column] as Label).text = values[player][column]
	_set_tab(title, true)
	var tween: Tween = _new_tween()
	tween.tween_method(_set_scores_shown, _scores_shown, 0.0, WIPE_TIME)
	tween.parallel().tween_method(_set_statistic_open, 0.0, 1.0, WIPE_TIME)
	tween.tween_property(_statistics, "modulate:a", 1.0, FADE_TIME)
	tween.parallel()
	_tween_tab(tween, TAB_HEIGHT)
	_hide_after(seconds)


func _hide_after(seconds: float) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	_graphic_timer = timer
	await timer.timeout
	if _graphic_timer == timer:
		_hide_graphic()


## Slides the tab down behind the panel and, after a statistic, brings the scores back.
func _hide_graphic() -> void:
	_graphic_timer = null
	var tween: Tween = _new_tween()
	_tween_tab(tween, 0.0)
	if _statistic_open > 0.0:
		tween.parallel().tween_property(_statistics, "modulate:a", 0.0, FADE_TIME)
		tween.tween_method(_set_statistic_open, _statistic_open, 0.0, WIPE_TIME)
		tween.parallel().tween_method(_set_scores_shown, _scores_shown, _scores_width, WIPE_TIME)


## Ends a shown caption or statistic at once, for the next one.
func _hide_graphic_now() -> void:
	_graphic_timer = null
	if _tween:
		_tween.kill()
	_tab_shown = 0.0
	_statistics.modulate.a = 0.0
	_statistic_open = 0.0
	_scores_shown = _scores_width
	_reveal = 1.0
	_layout()


func _tween_tab(tween: Tween, shown: float) -> void:
	(
		tween
		. tween_method(_set_tab_shown, _tab_shown, shown, TAB_TIME)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func _new_tween() -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	return _tween


func _set_scores_shown(width: float) -> void:
	_scores_shown = width
	_layout()


func _set_statistic_open(share: float) -> void:
	_statistic_open = share
	_layout()


func _set_tab_shown(height: float) -> void:
	_tab_shown = height
	_layout()


func _set_reveal(share: float) -> void:
	_reveal = share
	_layout()


func _set_tab(text: String, with_ibm: bool) -> void:
	_tab_label.text = text
	_tab_ibm.visible = with_ibm
	var left: float = IBM_WIDTH if with_ibm else 0.0
	var width: float = _text_width(_tab_label) + TAB_PADDING * 2.0
	_tab_band.position = Vector2(left, 0.0)
	_tab_band.size = Vector2(width, TAB_HEIGHT)
	_tab_label.position = Vector2(TAB_PADDING, 0.0)
	_tab_label.size = Vector2(width - TAB_PADDING * 2.0, TAB_HEIGHT)
	_tab.size = Vector2(left + width, TAB_HEIGHT)


func _set_games_columns(columns: int) -> void:
	_games_columns = columns
	_scores_width = SERVE_WIDTH + columns * GAMES_WIDTH + POINTS_BOX.x + POINTS_RIGHT + 6.0
	for player in 2:
		for i in (_games[player] as Array).size():
			(_games[player][i] as Label).visible = i < columns


## Places everything for the current widths and animation state. The panel is as wide as the
## names and the shown scores, or the statistic's columns while it opens.
func _layout() -> void:
	var statistics_width: float = STATISTIC_WIDTHS.x + STATISTIC_WIDTHS.y
	var content: float = maxf(_scores_shown, statistics_width * _statistic_open)
	var panel_width: float = (_names_width + content) * _reveal
	var height: float = ROW_HEIGHT * 2.0
	_panel.size = Vector2(panel_width, height)
	_background.size = _panel.size
	_sheen.size = _panel.size
	_glow.size = Vector2(panel_width, 3.0)
	_separator.position = Vector2(8.0, ROW_HEIGHT)
	_separator.size = Vector2(maxf(panel_width - 16.0, 0.0), 1.0)
	_tab.position = Vector2(0.0, -_tab_shown)
	_tab.visible = _reveal >= 1.0
	for player in 2:
		var top: float = player * ROW_HEIGHT
		_seeds[player].position = Vector2(SEED_LEFT, top)
		_seeds[player].size = Vector2(NAME_LEFT - SEED_LEFT - 8.0, ROW_HEIGHT)
		_names[player].position = Vector2(NAME_LEFT, top)
		_names[player].size = Vector2(_text_width(_names[player]), ROW_HEIGHT)
		_countries[player].position = Vector2(
			NAME_LEFT + _text_width(_names[player]) + COUNTRY_GAP, top + 2.0
		)
		_countries[player].size = Vector2(60.0, ROW_HEIGHT)
		# Scores, laid out from their right end, wiped from the right
		_point_boxes[player].position = Vector2(
			_scores_width - POINTS_RIGHT - 6.0 - POINTS_BOX.x,
			top + (ROW_HEIGHT - POINTS_BOX.y) * 0.5
		)
		_point_boxes[player].size = POINTS_BOX
		_points[player].size = POINTS_BOX
		var games_right: float = _point_boxes[player].position.x - 4.0
		for i in _games_columns:
			var label: Label = _games[player][i]
			label.position = Vector2(games_right - (_games_columns - i) * GAMES_WIDTH, top)
			label.size = Vector2(GAMES_WIDTH, ROW_HEIGHT)
		var swoosh_right: float = games_right - _games_columns * GAMES_WIDTH - 8.0
		_serve_icons[player].position = Vector2(swoosh_right - 46.0, top + 13.0)
		_serve_icons[player].size = Vector2(46.0, 17.0)
		var values: Array = _statistic_values[player]
		(values[0] as Label).position = Vector2(0.0, top)
		(values[0] as Label).size = Vector2(STATISTIC_WIDTHS.x, ROW_HEIGHT)
		(values[1] as Label).position = Vector2(STATISTIC_WIDTHS.x, top)
		(values[1] as Label).size = Vector2(STATISTIC_WIDTHS.y - 10.0, ROW_HEIGHT)
	_scores.position = Vector2(_names_width, 0.0)
	_scores.size = Vector2(_scores_shown, height)
	_statistics.position = Vector2(_names_width, 0.0)
	_statistics.size = Vector2(statistics_width, height)


func _fit_to_screen() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var factor: float = screen.y / DESIGN_HEIGHT
	scale = Vector2.ONE * factor
	position = Vector2(MARGIN.x * factor, screen.y - (MARGIN.y + ROW_HEIGHT * 2.0) * factor)


func _build() -> void:
	_tab = Control.new()
	add_child(_tab)
	_tab_ibm = ColorRect.new()
	_tab_ibm.color = Color(0.02, 0.02, 0.03)
	_tab_ibm.size = Vector2(IBM_WIDTH, TAB_HEIGHT)
	_tab.add_child(_tab_ibm)
	var ibm := TextureRect.new()
	var logo := AtlasTexture.new()
	logo.atlas = UsOpenLogos.ATLAS
	var rect: Rect2 = UsOpenLogos.RECTS[&"ibm"]
	var atlas_size: Vector2 = UsOpenLogos.ATLAS.get_size()
	logo.region = Rect2(rect.position * atlas_size, rect.size * atlas_size)
	ibm.texture = logo
	ibm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ibm.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ibm.position = Vector2(8.0, 6.0)
	ibm.size = Vector2(IBM_WIDTH - 16.0, TAB_HEIGHT - 12.0)
	_tab_ibm.add_child(ibm)
	_tab_band = ColorRect.new()
	_tab_band.color = YELLOW
	_tab.add_child(_tab_band)
	_tab_label = _label(BLACK_FONT, 23, NAVY, HORIZONTAL_ALIGNMENT_LEFT)
	_tab_band.add_child(_tab_label)

	_panel = Control.new()
	_panel.clip_contents = true
	add_child(_panel)
	_background = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = NAVY
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	_background.add_theme_stylebox_override("panel", style)
	_panel.add_child(_background)
	_sheen = TextureRect.new()
	_sheen.texture = _gradient(
		[Color(1, 1, 1, 0.0), Color(0.55, 0.7, 1.0, 0.07), Color(0.6, 0.75, 1.0, 0.2)],
		Vector2(0.0, 0.0),
		Vector2(1.0, 1.0)
	)
	_sheen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.add_child(_sheen)
	_glow = TextureRect.new()
	_glow.texture = _gradient(
		[Color(GLOW, 0.0), Color(GLOW, 0.9), Color(GLOW, 0.0)], Vector2(0.0, 0.5), Vector2(1.0, 0.5)
	)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.add_child(_glow)
	_separator = ColorRect.new()
	_separator.color = Color(BORDER, 0.55)
	_panel.add_child(_separator)

	_scores = Control.new()
	_scores.clip_contents = true
	_panel.add_child(_scores)
	_statistics = Control.new()
	_statistics.modulate.a = 0.0
	_panel.add_child(_statistics)
	for player in 2:
		var seed_label: Label = _label(
			BOLD_FONT, 20, Color(WHITE, 0.85), HORIZONTAL_ALIGNMENT_CENTER
		)
		_panel.add_child(seed_label)
		_seeds.append(seed_label)
		var name_label: Label = _label(BLACK_FONT, 31, WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		_panel.add_child(name_label)
		_names.append(name_label)
		var country: Label = _label(BOLD_FONT, 15, Color(WHITE, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
		_panel.add_child(country)
		_countries.append(country)
		var icon := TextureRect.new()
		icon.texture = SWOOSH
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_scores.add_child(icon)
		_serve_icons.append(icon)
		for i in 5:
			var games_label: Label = _label(BLACK_FONT, 30, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			_scores.add_child(games_label)
			_games[player].append(games_label)
		var box := Panel.new()
		var box_style := StyleBoxFlat.new()
		box_style.bg_color = WHITE
		box_style.set_corner_radius_all(2)
		box.add_theme_stylebox_override("panel", box_style)
		_scores.add_child(box)
		_point_boxes.append(box)
		var points: Label = _label(BLACK_FONT, 27, NAVY, HORIZONTAL_ALIGNMENT_CENTER)
		box.add_child(points)
		_points.append(points)
		for column in 2:
			var value: Label = _label(BLACK_FONT, 29, WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
			_statistics.add_child(value)
			_statistic_values[player].append(value)


func _label(font: Font, size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _gradient(colors: Array[Color], from: Vector2, to: Vector2) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	texture.width = 64
	texture.height = 64
	return texture


func _text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	return (
		font
		. get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")
		)
		. x
	)


func _point_text(point: int) -> String:
	match point:
		Score.TennisPoint.FIFTEEN:
			return "15"
		Score.TennisPoint.THIRTY:
			return "30"
		Score.TennisPoint.FORTY:
			return "40"
		Score.TennisPoint.AD:
			return "AD"
	return "0"
