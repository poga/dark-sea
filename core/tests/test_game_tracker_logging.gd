extends GutTest

var tracker: Node

func before_each():
	tracker = load("res://addons/game_tracker/game_tracker.gd").new()
	add_child(tracker)
	tracker.init({"endpoint": "https://example.com", "game": "test"})

func after_each():
	tracker.queue_free()

func test_log_info_queues_entry():
	tracker.log_info("Test message", {"key": "value"})

	assert_eq(tracker._log_queue.size(), 1)
	assert_eq(tracker._log_queue[0].level, "info")
	assert_eq(tracker._log_queue[0].msg, "Test message")
	assert_eq(tracker._log_queue[0].data.key, "value")

func test_log_warn_queues_entry():
	tracker.log_warn("Warning message")

	assert_eq(tracker._log_queue.size(), 1)
	assert_eq(tracker._log_queue[0].level, "warn")

func test_log_error_queues_entry():
	tracker.log_error("Error message", {"code": 500})

	assert_eq(tracker._log_queue[0].level, "error")
	assert_eq(tracker._log_queue[0].data.code, 500)

func test_log_debug_queues_entry():
	tracker.log_debug("Debug message")

	assert_eq(tracker._log_queue[0].level, "debug")

func test_log_includes_timestamp():
	tracker.log_info("Test")

	assert_true(tracker._log_queue[0].has("ts"))
	assert_true(tracker._log_queue[0].ts > 0)

func test_queue_drops_oldest_when_full():
	for i in range(tracker.MAX_QUEUE_SIZE + 10):
		tracker.log_info("Message %d" % i)

	assert_eq(tracker._log_queue.size(), tracker.MAX_QUEUE_SIZE)
	# First message should be "Message 10" (0-9 dropped)
	assert_eq(tracker._log_queue[0].msg, "Message 10")
