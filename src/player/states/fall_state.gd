extends PlayerState


func physics_update(delta: float) -> void:
	p.apply_planar_movement(delta, p.desired_speed(), Player.AIR_ACCEL, Player.AIR_DECEL)
	p.apply_gravity(delta)

	if try_dodge() or try_jump():
		return
	if p.is_on_floor():
		transition_to(&"Land", {"impact": absf(p.velocity.y)})
