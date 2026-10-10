extends TestCase

var buf: InputBuffer


func before_each() -> void:
	buf = InputBuffer.new(7)


func test_consumes_within_window() -> void:
	buf.press(&"attack", 10)
	assert_true(buf.consume(&"attack", 12), "press 2 frames old should fire")


func test_fires_on_same_frame() -> void:
	buf.press(&"attack", 10)
	assert_true(buf.consume(&"attack", 10), "same-frame press should fire")


func test_last_live_frame_is_window_minus_one() -> void:
	buf.press(&"attack", 10)
	assert_true(buf.has(&"attack", 16), "frame 16 is 6 frames old, still live")


func test_expires_exactly_at_window() -> void:
	buf.press(&"attack", 10)
	assert_false(buf.has(&"attack", 17), "7 frames old is outside a 7-frame window")
	assert_false(buf.consume(&"attack", 17), "expired press must not fire")


func test_consume_is_single_shot() -> void:
	buf.press(&"dodge", 5)
	assert_true(buf.consume(&"dodge", 6))
	assert_false(buf.consume(&"dodge", 6), "a consumed press must not fire twice")


func test_actions_are_independent() -> void:
	buf.press(&"attack", 10)
	buf.press(&"jump", 10)
	assert_true(buf.consume(&"attack", 11))
	assert_true(buf.has(&"jump", 11), "consuming one action must not clear another")


func test_newer_press_overwrites_older() -> void:
	buf.press(&"attack", 1)
	buf.press(&"attack", 20)
	assert_true(buf.consume(&"attack", 22), "most recent intent wins")


func test_age_reports_frames_since_press() -> void:
	buf.press(&"gun", 30)
	assert_eq(buf.age(&"gun", 34), 4)
	assert_eq(buf.age(&"heavy", 34), -1, "unbuffered action reports -1")


func test_clear_drops_everything() -> void:
	buf.press(&"attack", 1)
	buf.press(&"jump", 1)
	buf.clear()
	assert_false(buf.has(&"attack", 2))
	assert_false(buf.has(&"jump", 2))


func test_custom_window_is_respected() -> void:
	var wide := InputBuffer.new(15)
	wide.press(&"attack", 0)
	assert_true(wide.has(&"attack", 14))
	assert_false(wide.has(&"attack", 15))
