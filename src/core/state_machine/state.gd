extends Node
class_name State
## Base class for a single state. One behaviour per node, so adding a move
## never requires editing an existing state.
##
## All timing is in physics frames at the fixed 60Hz tick. `frames_elapsed` is
## maintained by the StateMachine and resets on every entry.

var machine: StateMachine
var actor: Node

var frames_elapsed := 0


## Called once by the StateMachine when `actor` is assigned, before any
## enter(). States override this to cache a typed reference.
func on_actor_assigned() -> void:
	pass


## `msg` carries hand-off data between states (e.g. the launch velocity a hit
## state passes to a knockback state).
func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


## Runs once per physics frame while this state is current.
func physics_update(_delta: float) -> void:
	pass


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	machine.transition_to(state_name, msg)


## 0..1 through a state of known length. Finite states override `duration()`;
## open-ended states report 0 and the rig treats them as untimed.
func duration() -> int:
	return 0


func state_progress() -> float:
	var d := duration()
	if d <= 0:
		return 0.0
	return clampf(float(frames_elapsed) / float(d), 0.0, 1.0)
