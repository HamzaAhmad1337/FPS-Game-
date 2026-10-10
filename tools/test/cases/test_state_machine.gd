extends TestCase

var sm: StateMachine
var a: State
var b: State


func before_each() -> void:
	sm = StateMachine.new()
	a = State.new()
	a.name = "A"
	b = State.new()
	b.name = "B"
	sm.add_child(a)
	sm.add_child(b)
	sm.initial_state = NodePath("A")
	sm.setup(null)


func after_each() -> void:
	sm.free()


func test_starts_in_initial_state() -> void:
	assert_eq(sm.current_name, &"A")
	assert_true(sm.current == a)


func test_transition_updates_current_and_previous() -> void:
	sm.transition_to(&"B")
	assert_eq(sm.current_name, &"B")
	assert_eq(sm.previous_name, &"A")


func test_frames_elapsed_counts_physics_updates() -> void:
	sm.physics_update(0.016)
	sm.physics_update(0.016)
	assert_eq(a.frames_elapsed, 2)


func test_frames_elapsed_resets_on_entry() -> void:
	sm.physics_update(0.016)
	sm.physics_update(0.016)
	sm.transition_to(&"B")
	assert_eq(b.frames_elapsed, 0)


func test_reentering_same_state_resets_it() -> void:
	sm.physics_update(0.016)
	sm.physics_update(0.016)
	# Combo links re-enter the attack state, so this must reset rather than
	# be ignored as a no-op.
	sm.transition_to(&"A")
	assert_eq(a.frames_elapsed, 0)
	assert_eq(sm.current_name, &"A")


func test_has_state() -> void:
	assert_true(sm.has_state(&"A"))
	assert_false(sm.has_state(&"Nope"))


func test_state_progress_is_zero_for_open_ended_states() -> void:
	assert_eq(a.duration(), 0)
	assert_almost_eq(a.state_progress(), 0.0)
