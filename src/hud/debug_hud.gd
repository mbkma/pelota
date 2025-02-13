extends CanvasLayer

@export var fps: Label
@export var frame_time: Label
@export var frame_number: Label
@export var frame_history_gpu_max: Label
@export var frame_history_gpu_last: Label

## The number of frames to keep in history for graph drawing and best/worst calculations.
## Currently, this also affects how FPS is measured.
const HISTORY_NUM_FRAMES = 150

const GRAPH_SIZE = Vector2(150, 25)
const GRAPH_MIN_FPS = 10
const GRAPH_MAX_FPS = 160
const GRAPH_MIN_FRAMETIME = 1.0 / GRAPH_MIN_FPS
const GRAPH_MAX_FRAMETIME = 1.0 / GRAPH_MAX_FPS

## Debug menu display style.
enum Style {
	HIDDEN,  ## Debug menu is hidden.
	VISIBLE_COMPACT,  ## Debug menu is visible, with only the FPS, FPS cap (if any) and time taken to render the last frame.
	VISIBLE_DETAILED,  ## Debug menu is visible with full information, including graphs.
	MAX,  ## Represents the size of the Style enum.
}

## The style to use when drawing the debug menu.
var style := Style.HIDDEN:
	set(value):
		style = value
		match style:
			Style.HIDDEN:
				visible = false
			Style.VISIBLE_COMPACT, Style.VISIBLE_DETAILED:
				visible = true
				frame_number.visible = style == Style.VISIBLE_DETAILED

# Value of `Time.get_ticks_usec()` on the previous frame.
var last_tick := 0

## Returns the sum of all values of an array (use as a parameter to `Array.reduce()`).
var sum_func := func avg(accum: float, number: float) -> float: return accum + number

# History of the last `HISTORY_NUM_FRAMES` rendered frames.
var frame_history_total: Array[float] = []
var frame_history_cpu: Array[float] = []
var frame_history_gpu: Array[float] = []
var fps_history: Array[float] = []  # Only used for graphs.

var frametime_avg := GRAPH_MIN_FRAMETIME
var frametime_cpu_avg := GRAPH_MAX_FRAMETIME
var frametime_gpu_avg := GRAPH_MIN_FRAMETIME
var frames_per_second := float(GRAPH_MIN_FPS)
var frame_time_gradient := Gradient.new()


func _init() -> void:
	# This must be done here instead of `_ready()` to avoid having `visibility_changed` be emitted immediately.
	visible = false


func _ready() -> void:
	fps_history.resize(HISTORY_NUM_FRAMES)
	frame_history_total.resize(HISTORY_NUM_FRAMES)
	frame_history_cpu.resize(HISTORY_NUM_FRAMES)
	frame_history_gpu.resize(HISTORY_NUM_FRAMES)

	# NOTE: Both FPS and frametimes are colored following FPS logic
	# (red = 10 FPS, yellow = 60 FPS, green = 110 FPS, cyan = 160 FPS).
	# This makes the color gradient non-linear.
	# Colors are taken from <https://tailwindcolor.com/>.
	frame_time_gradient.set_color(0, Color8(239, 68, 68))  # red-500
	frame_time_gradient.set_color(1, Color8(56, 189, 248))  # light-blue-400
	frame_time_gradient.add_point(0.3333, Color8(250, 204, 21))  # yellow-400
	frame_time_gradient.add_point(0.6667, Color8(128, 226, 95))  # 50-50 mix of lime-400 and green-400


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_debug_menu"):
		style = wrapi(style + 1, 0, Style.MAX) as Style


func _process(_delta: float) -> void:
	if visible:
		# Difference between the last two rendered frames in milliseconds.
		var frametime := (Time.get_ticks_usec() - last_tick) * 0.001

		frame_history_total.push_back(frametime)
		if frame_history_total.size() > HISTORY_NUM_FRAMES:
			frame_history_total.pop_front()

		# Frametimes are colored following FPS logic (red = 10 FPS, yellow = 60 FPS, green = 110 FPS, cyan = 160 FPS).
		# This makes the color gradient non-linear.
		var viewport_rid := get_viewport().get_viewport_rid()
		var frametime_cpu := (
			RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
			+ RenderingServer.get_frame_setup_time_cpu()
		)
		frame_history_cpu.push_back(frametime_cpu)
		if frame_history_cpu.size() > HISTORY_NUM_FRAMES:
			frame_history_cpu.pop_front()

		var frametime_gpu_max: float = frame_history_gpu.max()
		frame_history_gpu_max.text = str(frametime_gpu_max).pad_decimals(2)
		frame_history_gpu_max.modulate = frame_time_gradient.sample(
			remap(1000.0 / frametime_gpu_max, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)
		)

		frame_history_gpu_last.text = str("frametime_gpu").pad_decimals(2)
		frame_history_gpu_last.modulate = frame_time_gradient.sample(
			remap(1000.0 / randf(), GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)
		)

		frames_per_second = 1000.0 / frametime_avg
		fps_history.push_back(frames_per_second)
		if fps_history.size() > HISTORY_NUM_FRAMES:
			fps_history.pop_front()

		fps.text = str(floor(frames_per_second)) + " FPS"
		var frame_time_color := frame_time_gradient.sample(
			remap(frames_per_second, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)
		)
		fps.modulate = frame_time_color

		frame_time.text = str(frametime).pad_decimals(2) + " mspf"
		frame_time.modulate = frame_time_color

		var vsync_string := ""
		match DisplayServer.window_get_vsync_mode():
			DisplayServer.VSYNC_ENABLED:
				vsync_string = "V-Sync"
			DisplayServer.VSYNC_ADAPTIVE:
				vsync_string = "Adaptive V-Sync"
			DisplayServer.VSYNC_MAILBOX:
				vsync_string = "Mailbox V-Sync"

		if Engine.max_fps > 0 or OS.low_processor_usage_mode:
			# Display FPS cap determined by `Engine.max_fps` or low-processor usage mode sleep duration
			# (the lowest FPS cap is used).
			var low_processor_max_fps := roundi(1000000.0 / OS.low_processor_usage_mode_sleep_usec)
			var fps_cap := low_processor_max_fps
			if Engine.max_fps > 0:
				fps_cap = mini(Engine.max_fps, low_processor_max_fps)
			frame_time.text += " (cap: " + str(fps_cap) + " FPS"

			if not vsync_string.is_empty():
				frame_time.text += " + " + vsync_string

			frame_time.text += ")"
		else:
			if not vsync_string.is_empty():
				frame_time.text += " (" + vsync_string + ")"

		frame_number.text = "Frame: " + str(Engine.get_frames_drawn())

	last_tick = Time.get_ticks_usec()


func _on_visibility_changed() -> void:
	if visible:
		# Reset graphs to prevent them from looking strange before `HISTORY_NUM_FRAMES` frames
		# have been drawn.
		var frametime_last := (Time.get_ticks_usec() - last_tick) * 0.001
		fps_history.resize(HISTORY_NUM_FRAMES)
		fps_history.fill(1000.0 / frametime_last)
		frame_history_total.resize(HISTORY_NUM_FRAMES)
		frame_history_total.fill(frametime_last)
		frame_history_cpu.resize(HISTORY_NUM_FRAMES)
		var viewport_rid := get_viewport().get_viewport_rid()
		frame_history_cpu.fill(
			(
				RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
				+ RenderingServer.get_frame_setup_time_cpu()
			)
		)
		frame_history_gpu.resize(HISTORY_NUM_FRAMES)
		frame_history_gpu.fill(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
