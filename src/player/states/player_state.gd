extends State
class_name PlayerState
## Shared base for player states: typed actor plus the universal cancels.

var p: Player


func on_actor_assigned() -> void:
	p = actor as Player


## Dodge and jump are available out of almost every state. Checking `has`
## before `consume` matters: a jump pressed while airborne past coyote time
## must stay buffered so it fires on landing instead of being eaten here.
func try_dodge() -> bool:
	if p.input_buffer.has(&"dodge", p.frame):
		p.input_buffer.consume(&"dodge", p.frame)
		transition_to(&"Dodge")
		return true
	return false


func try_jump() -> bool:
	if p.can_coyote_jump() and p.input_buffer.has(&"jump", p.frame):
		p.input_buffer.consume(&"jump", p.frame)
		transition_to(&"Jump")
		return true
	return false


## Keeps the body pinned to the floor; without a small downward bias
## is_on_floor() flickers on slopes and steps.
func stick_to_floor() -> void:
	if p.is_on_floor() and p.velocity.y <= 0.0:
		p.velocity.y = -2.0


func to_idle_or_move() -> void:
	if p.move_input().length() > 0.15:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
