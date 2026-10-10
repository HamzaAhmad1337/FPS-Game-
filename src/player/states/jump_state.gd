extends PlayerState
## Rising half of a jump. Splitting rise from fall keeps the two gravity
## profiles and the two air poses independent.


func enter(_msg: Dictionary = {}) -> void:
	p.velocity.y = p.jump_velocity()
	# Consumed so the ground cannot re-trigger it on the same press.
	p.frames_since_grounded = Player.COYOTE_FRAMES + 1


func physics_update(delta: float) -> void:
	p.apply_planar_movement(delta, p.desired_speed(), Player.AIR_ACCEL, Player.AIR_DECEL)
	p.apply_gravity(delta)

	if try_dodge():
		return
	if p.velocity.y <= 0.0:
		transition_to(&"Fall")
