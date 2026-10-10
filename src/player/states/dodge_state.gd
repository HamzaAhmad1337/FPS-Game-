extends PlayerState
## Committed roll with an invulnerability window.
##
## Direction is locked on entry: a dodge that steers mid-animation removes the
## commitment that makes dodging a decision rather than a free escape.

var _direction := Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	var input := p.move_input()
	if input.length() > 0.15:
		_direction = Vector3(input.x, 0.0, -input.y * Player.DEPTH_SPEED_SCALE).normalized()
	else:
		# No stick input dodges backwards, away from the threat being faced.
		_direction = Vector3(-p.facing, 0.0, 0.0)
	p.velocity.y = 0.0


func duration() -> int:
	return Player.DODGE_FRAMES


func physics_update(_delta: float) -> void:
	# Speed tapers across the roll so the recovery reads as a recovery.
	var t := float(frames_elapsed) / float(Player.DODGE_FRAMES)
	var speed := Player.DODGE_SPEED * (1.0 - smoothstep(0.45, 1.0, t))
	p.velocity.x = _direction.x * speed
	p.velocity.z = _direction.z * speed
	stick_to_floor()

	if frames_elapsed == Player.DODGE_IFRAME_START:
		p.set_invulnerable_for(Player.DODGE_IFRAME_END - Player.DODGE_IFRAME_START)

	if frames_elapsed >= Player.DODGE_FRAMES:
		to_idle_or_move()
