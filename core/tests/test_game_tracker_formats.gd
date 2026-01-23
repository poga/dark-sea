extends GutTest

var tracker: Node

func before_each():
	tracker = load("res://addons/game_tracker/game_tracker.gd").new()
	add_child(tracker)
	tracker.init({
		"endpoint": "https://example.com",
		"game": "test-game",
		"version": "1.0.0",
		"environment": "test"
	})

func after_each():
	tracker.queue_free()

func test_format_loki_payload():
	tracker.log_error("Test error", {"detail": "info"})

	var payload = tracker._format_loki_payload()

	assert_true(payload.has("streams"))
	assert_eq(payload.streams.size(), 1)

	var stream = payload.streams[0]
	assert_eq(stream.stream.game, "test-game")
	assert_eq(stream.stream.env, "test")
	assert_eq(stream.stream.level, "error")

	assert_eq(stream.values.size(), 1)
	# values[0] is [timestamp_ns, json_string]
	assert_eq(stream.values[0].size(), 2)

func test_loki_groups_by_level():
	tracker.log_error("Error 1")
	tracker.log_info("Info 1")
	tracker.log_error("Error 2")

	var payload = tracker._format_loki_payload()

	# Should have 2 streams: one for error, one for info
	assert_eq(payload.streams.size(), 2)

func test_loki_payload_includes_context():
	tracker.set_user({"id": "player_1"})
	tracker.set_tag("build", "demo")
	tracker.log_info("Test")

	var payload = tracker._format_loki_payload()
	var log_json = JSON.parse_string(payload.streams[0].values[0][1])

	assert_eq(log_json.user.id, "player_1")
	assert_eq(log_json.tags.build, "demo")

func test_format_prometheus_payload():
	tracker.increment("enemies_killed", {"level": "forest"}, 5)
	tracker.gauge("player_health", 85, {"player_id": "p1"})

	var payload = tracker._format_prometheus_payload()

	# Prometheus remote write uses a specific structure
	assert_true(payload.has("timeseries"))
	assert_eq(payload.timeseries.size(), 2)

func test_prometheus_metric_structure():
	tracker.increment("test_counter", {"region": "us"})

	var payload = tracker._format_prometheus_payload()
	var ts = payload.timeseries[0]

	# Should have labels array and samples array
	assert_true(ts.has("labels"))
	assert_true(ts.has("samples"))

	# Labels should include __name__, game, env, and custom labels
	var label_names = []
	for label in ts.labels:
		label_names.append(label.name)
	assert_true("__name__" in label_names)
	assert_true("game" in label_names)
	assert_true("region" in label_names)

func test_prometheus_counter_has_total_suffix():
	tracker.increment("enemies_killed")

	var payload = tracker._format_prometheus_payload()
	var name_label = null
	for label in payload.timeseries[0].labels:
		if label.name == "__name__":
			name_label = label
			break

	assert_true(name_label.value.ends_with("_total"))
