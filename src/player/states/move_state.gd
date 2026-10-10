extends PlayerState


func physics_update(delta: float) -> void:
	p.apply_planar_movement(delta, p.desired_speed(), Player.GROUND_ACCEL, Player.GROUND_DECEL)
	stick_to_floor()

	if try_dodge() or try_jump():
		return
	if not p.is_on_floor():
		transition_to(&"Fall")
		return
	# Requires both no input and near-zero speed, so the deceleration ramp
	# plays out in the run pose instead of snapping to idle on key release.
	if p.move_input().length() <= 0.15 and p.planar_speed() < 0.4:
		transition_to(&"Idle")
