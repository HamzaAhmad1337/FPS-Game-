extends PlayerState


func physics_update(delta: float) -> void:
	p.apply_planar_movement(delta, 0.0, 0.0, Player.GROUND_DECEL)
	stick_to_floor()

	if try_dodge() or try_jump():
		return
	if not p.is_on_floor():
		transition_to(&"Fall")
		return
	if p.move_input().length() > 0.15:
		transition_to(&"Move")
