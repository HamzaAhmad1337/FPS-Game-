extends Node
class_name StateMachine
## Drives one State child at a time.
##
## Deliberately does not tick itself: the owning actor calls physics_update so
## combat ordering (hitstop first, then state logic, then physics move) stays
## explicit and debuggable rather than depending on node tree order.

signal state_changed(from: StringName, to: StringName)

@export var initial_state: NodePath

var current: State
var current_name: StringName = &""
var previous_name: StringName = &""

var _states: Dictionary = {}
var _actor: Node


func setup(actor: Node) -> void:
	_actor = actor
	for child in get_children():
		if child is State:
			_states[StringName(child.name)] = child
			child.machine = self
			child.actor = actor
			child.on_actor_assigned()
		else:
			push_warning("StateMachine child %s is not a State" % child.name)

	var start: State = get_node_or_null(initial_state) as State
	if start == null:
		push_error("StateMachine has no valid initial_state")
		return
	current = start
	current_name = StringName(start.name)
	current.frames_elapsed = 0
	current.enter()


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: no state named '%s'" % state_name)
		return
	# Re-entering the same state is a legitimate reset (e.g. combo link
	# restarting the attack state), so it is allowed rather than ignored.
	var from := current_name
	if current != null:
		current.exit()
	previous_name = from
	current = _states[state_name]
	current_name = state_name
	current.frames_elapsed = 0
	current.enter(msg)
	state_changed.emit(from, state_name)


func physics_update(delta: float) -> void:
	if current == null:
		return
	current.physics_update(delta)
	current.frames_elapsed += 1


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)
