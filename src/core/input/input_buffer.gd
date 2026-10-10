extends RefCounted
class_name InputBuffer
## Stores player intent for a short window so a press made during an attack's
## recovery frames still fires the moment the state machine allows it.
##
## Without this, correct combat code still feels unresponsive: the player
## presses on the frame they see the hit land, which is several frames before
## the move is cancellable, and the input is silently thrown away.
##
## Windows are measured in physics frames at a fixed 60Hz tick, not seconds,
## so buffering behaviour cannot drift with framerate.

## 7 frames at 60Hz (~0.117s), the common fighting/action game default.
const DEFAULT_WINDOW_FRAMES := 7

var window_frames: int
var _pressed_at: Dictionary = {}   # action name -> frame it was pressed


func _init(window: int = DEFAULT_WINDOW_FRAMES) -> void:
	window_frames = window


## Record a press. A newer press of the same action overwrites the older one;
## the player's most recent intent is the one that matters.
func press(action: StringName, frame: int) -> void:
	_pressed_at[action] = frame


## Poll the real input device. Call once per physics frame.
func poll(actions: Array, frame: int) -> void:
	for action in actions:
		if Input.is_action_just_pressed(action):
			press(action, frame)


## True if the action was pressed within the window and has not been consumed.
func has(action: StringName, frame: int) -> bool:
	if not _pressed_at.has(action):
		return false
	return frame - int(_pressed_at[action]) < window_frames


## Consume the buffered press if it is still live. Returns whether it fired.
func consume(action: StringName, frame: int) -> bool:
	if not has(action, frame):
		# An expired entry is dropped here so stale intent cannot resurface if
		# the clock is ever rewound (replays, rollback).
		_pressed_at.erase(action)
		return false
	_pressed_at.erase(action)
	return true


## Age of the buffered press in frames, or -1 when nothing is buffered.
func age(action: StringName, frame: int) -> int:
	if not _pressed_at.has(action):
		return -1
	return frame - int(_pressed_at[action])


func clear() -> void:
	_pressed_at.clear()
