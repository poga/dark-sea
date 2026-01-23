extends GutTest

var tracker: Node

func before_each():
	tracker = load("res://addons/game_tracker/game_tracker.gd").new()
	add_child(tracker)
	tracker.init({"endpoint": "https://example.com", "game": "test"})

func after_each():
	tracker.queue_free()

func test_flush_clears_log_queue():
	tracker.log_info("Test 1")
	tracker.log_info("Test 2")
	assert_eq(tracker._log_queue.size(), 2)

	tracker._flush_logs()

	assert_eq(tracker._log_queue.size(), 0)

func test_flush_clears_metric_queue():
	tracker.increment("test_1")
	tracker.gauge("test_2", 50)
	assert_eq(tracker._metric_queue.size(), 2)

	tracker._flush_metrics()

	assert_eq(tracker._metric_queue.size(), 0)

func test_flush_clears_trace_queue():
	var span = tracker.start_span("test")
	span.end()
	assert_eq(tracker._trace_queue.size(), 1)

	tracker._flush_traces()

	assert_eq(tracker._trace_queue.size(), 0)

func test_flush_does_nothing_when_queue_empty():
	# Should not error when queue is empty
	tracker._flush_logs()
	tracker._flush_metrics()
	tracker._flush_traces()

	assert_true(true, "No errors when flushing empty queues")

func test_flush_all_flushes_everything():
	tracker.log_info("Log")
	tracker.increment("metric")
	var span = tracker.start_span("trace")
	span.end()

	tracker._flush_all()

	assert_eq(tracker._log_queue.size(), 0)
	assert_eq(tracker._metric_queue.size(), 0)
	assert_eq(tracker._trace_queue.size(), 0)
