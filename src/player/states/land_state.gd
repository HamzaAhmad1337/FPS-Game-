extends PlayerState
## Short recovery that gives the landing weight. Fully cancellable, so it
## never costs the player control.

const BASE_FRAMES := 6
const MAX_FRAMES := 14
const HARD_LANDING_SPEED := 16.0

var _frames := BASE_FRAMES


func enter(msg: Dictionary = {}) -> void:
	var impact: float = msg.get("impact", 0.0)
	_frames = int(lerpf(
		BASE_FRAMES, MAX_FRAMES, clampf(impact / HARD_LANDING_SPEED, 0.0, 1.0)
	))
	p.velocity.y = 0.0


func duration() -> int:
	return _frames


func physics_update(delta: float) -> void:
	p.apply_planar_movement(delta, 0.0, 0.0, Player.GROUND_DECEL * 0.6)
	stick_to_floor()

	if try_dodge() or try_jump():
		return
	if frames_elapsed >= _frames:
		to_idle_or_move()
