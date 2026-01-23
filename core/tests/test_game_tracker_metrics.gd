extends GutTest

var tracker: Node

func before_each():
	tracker = load("res://addons/game_tracker/game_tracker.gd").new()
	add_child(tracker)
	tracker.init({"endpoint": "https://example.com", "game": "test"})

func after_each():
	tracker.queue_free()

func test_increment_queues_counter():
	tracker.increment("enemies_killed", {"level": "forest"})

	assert_eq(tracker._metric_queue.size(), 1)
	assert_eq(tracker._metric_queue[0].type, "counter")
	assert_eq(tracker._metric_queue[0].name, "enemies_killed")
	assert_eq(tracker._metric_queue[0].value, 1)
	assert_eq(tracker._metric_queue[0].labels.level, "forest")

func test_increment_with_amount():
	tracker.increment("gold_earned", {}, 50)

	assert_eq(tracker._metric_queue[0].value, 50)

func test_gauge_queues_gauge():
	tracker.gauge("player_health", 85, {"player_id": "123"})

	assert_eq(tracker._metric_queue.size(), 1)
	assert_eq(tracker._metric_queue[0].type, "gauge")
	assert_eq(tracker._metric_queue[0].name, "player_health")
	assert_eq(tracker._metric_queue[0].value, 85)

func test_histogram_queues_histogram():
	tracker.histogram("load_time_ms", 1250, {"scene": "level_3"})

	assert_eq(tracker._metric_queue.size(), 1)
	assert_eq(tracker._metric_queue[0].type, "histogram")
	assert_eq(tracker._metric_queue[0].name, "load_time_ms")
	assert_eq(tracker._metric_queue[0].value, 1250)

func test_metrics_include_timestamp():
	tracker.increment("test")

	assert_true(tracker._metric_queue[0].has("ts"))

func test_metric_queue_drops_oldest_when_full():
	for i in range(tracker.MAX_QUEUE_SIZE + 5):
		tracker.increment("metric_%d" % i)

	assert_eq(tracker._metric_queue.size(), tracker.MAX_QUEUE_SIZE)
