extends GutTest

var tracker: Node

func before_each():
	tracker = load("res://addons/game_tracker/game_tracker.gd").new()
	add_child(tracker)
	tracker.init({"endpoint": "https://example.com", "game": "test"})

func after_each():
	tracker.queue_free()

func test_start_span_returns_span():
	var span = tracker.start_span("test_operation")

	assert_not_null(span)
	assert_eq(span.name, "test_operation")

func test_span_has_trace_and_span_ids():
	var span = tracker.start_span("test_operation")

	assert_true(span.trace_id.length() > 0)
	assert_true(span.span_id.length() > 0)

func test_span_end_queues_trace():
	var span = tracker.start_span("test_operation", {"key": "value"})
	span.end()

	assert_eq(tracker._trace_queue.size(), 1)
	assert_eq(tracker._trace_queue[0].name, "test_operation")
	assert_true(tracker._trace_queue[0].has("start_time"))
	assert_true(tracker._trace_queue[0].has("end_time"))
	assert_eq(tracker._trace_queue[0].attributes.key, "value")

func test_nested_spans_share_trace_id():
	var parent = tracker.start_span("parent_op")
	var child = tracker.start_span("child_op", {}, parent)

	assert_eq(child.trace_id, parent.trace_id)
	assert_ne(child.span_id, parent.span_id)
	assert_eq(child.parent_span_id, parent.span_id)

func test_span_end_calculates_duration():
	var span = tracker.start_span("test_operation")
	# Small delay to ensure measurable duration
	await get_tree().create_timer(0.05).timeout
	span.end()

	var trace = tracker._trace_queue[0]
	assert_true(trace.end_time > trace.start_time)
