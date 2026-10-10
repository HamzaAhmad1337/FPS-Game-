extends Node
## Headless visual verification harness.
##
## Boots a target scene, drives scripted input on a fixed 60Hz tick, captures
## frames, and writes a contact sheet. This is the project's anti-regression
## eye: no gameplay feature is considered done until a sheet produced by this
## harness shows it working.
##
## Usage (see tools/verify/run_capture.sh):
##   godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##         --audio-driver Dummy --fixed-fps 60 --resolution 480x270 \
##         --script-main tools/verify/CaptureHarness.tscn -- \
##         --scene=res://levels/Arena01.tscn --frames=120 --every=6 \
##         --inputs=res://tools/verify/inputs/run_right.json \
##         --out=/abs/path/sheet.png

const DEFAULT_COLS := 6

var _target_scene_path := ""
var _inputs_path := ""
var _out_path := ""
var _dump_dir := ""
var _total_frames := 120
var _every := 6
var _cols := DEFAULT_COLS
var _settle_frames := 2

var _events: Array = []
var _auto_release: Dictionary = {}   # action -> frame at which to release
var _held: Dictionary = {}           # actions currently pressed by the harness
var _shots: Array[Image] = []
var _frame := 0
var _finished := false


func _ready() -> void:
	_parse_args()
	if _target_scene_path.is_empty():
		push_error("[capture] no --scene= given")
		get_tree().quit(2)
		return
	if not ResourceLoader.exists(_target_scene_path):
		push_error("[capture] scene not found: %s" % _target_scene_path)
		get_tree().quit(2)
		return

	if not _inputs_path.is_empty():
		_load_input_script(_inputs_path)

	var packed: PackedScene = load(_target_scene_path)
	var instance: Node = packed.instantiate()
	add_child(instance)
	print("[capture] scene=%s frames=%d every=%d shots=%d" % [
		_target_scene_path, _total_frames, _every, int(ceil(float(_total_frames) / _every))
	])

	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() != 2:
			continue
		var key := kv[0].lstrip("-")
		var val := kv[1]
		match key:
			"scene": _target_scene_path = val
			"inputs": _inputs_path = val
			"out": _out_path = val
			"dump-dir": _dump_dir = val
			"frames": _total_frames = int(val)
			"every": _every = maxi(1, int(val))
			"cols": _cols = maxi(1, int(val))
			"settle": _settle_frames = int(val)
			_: push_warning("[capture] unknown arg: %s" % arg)


func _load_input_script(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("[capture] input script not found: %s" % path)
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("events"):
		push_error("[capture] malformed input script: %s" % path)
		return
	_events = parsed["events"]
	# Validate every referenced action up front: a typo here would silently
	# produce a passing-looking capture of nothing happening.
	for ev in _events:
		for list_key in ["press", "release", "tap"]:
			for action in ev.get(list_key, []):
				if not InputMap.has_action(action):
					push_error("[capture] input script references unknown action: %s" % action)
	print("[capture] input script loaded: %d events" % _events.size())


func _process(_delta: float) -> void:
	if _finished:
		return
	_apply_input_for_frame(_frame)


func _apply_input_for_frame(f: int) -> void:
	for action in _auto_release.keys():
		if _auto_release[action] == f:
			_release(action)
	for ev in _events:
		if int(ev.get("frame", -1)) != f:
			continue
		for action in ev.get("press", []):
			_press(action)
		for action in ev.get("release", []):
			_release(action)
		for action in ev.get("tap", []):
			_press(action)
			_auto_release[action] = f + int(ev.get("tap_frames", 2))


func _press(action: String) -> void:
	if not InputMap.has_action(action):
		return
	Input.action_press(action)
	_held[action] = true


func _release(action: String) -> void:
	if not InputMap.has_action(action):
		return
	Input.action_release(action)
	_held.erase(action)
	_auto_release.erase(action)


func _on_frame_post_draw() -> void:
	if _finished:
		return
	# Give the renderer a couple of frames before trusting the backbuffer.
	if _frame >= _settle_frames and (_frame - _settle_frames) % _every == 0:
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			_shots.append(img)
			if not _dump_dir.is_empty():
				img.save_png("%s/frame_%04d.png" % [_dump_dir, _frame])
	_frame += 1
	if _frame > _total_frames:
		_finish()


func _finish() -> void:
	_finished = true
	for action in _held.keys():
		Input.action_release(action)
	if _shots.is_empty():
		push_error("[capture] captured 0 frames")
		get_tree().quit(3)
		return
	if not _out_path.is_empty():
		var err := _write_contact_sheet(_out_path)
		if err != OK:
			push_error("[capture] failed to write sheet: %s (err %d)" % [_out_path, err])
			get_tree().quit(4)
			return
	print("[capture] OK shots=%d out=%s" % [_shots.size(), _out_path])
	get_tree().quit(0)


## Tiles captured frames left-to-right, top-to-bottom, with a 2px separator so
## frame boundaries stay readable when the motion between them is subtle.
func _write_contact_sheet(path: String) -> Error:
	const PAD := 2
	var w := _shots[0].get_width()
	var h := _shots[0].get_height()
	var cols := mini(_cols, _shots.size())
	var rows := int(ceil(float(_shots.size()) / cols))
	var sheet := Image.create(
		cols * w + (cols + 1) * PAD,
		rows * h + (rows + 1) * PAD,
		false,
		Image.FORMAT_RGBA8
	)
	sheet.fill(Color(0.07, 0.07, 0.09, 1.0))
	for i in _shots.size():
		var img := _shots[i]
		if img.get_width() != w or img.get_height() != h:
			img.resize(w, h, Image.INTERPOLATE_NEAREST)
		var cx := i % cols
		var cy := i / cols
		sheet.blit_rect(
			img,
			Rect2i(0, 0, w, h),
			Vector2i(PAD + cx * (w + PAD), PAD + cy * (h + PAD))
		)
	return sheet.save_png(path)
