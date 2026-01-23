# GameTracker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a single-file GDScript observability addon that sends logs, metrics, and traces to Grafana Alloy.

**Architecture:** Single autoload singleton (`GameTracker`) with internal queues for logs, metrics, and traces. Batched HTTP sending via timer. Fire-and-forget, silent failures.

**Tech Stack:** GDScript, Godot 4.6, HTTPRequest node, GUT for testing

---

## Task 1: Create Addon Structure and Basic Initialization

**Files:**
- Create: `addons/game_tracker/plugin.cfg`
- Create: `addons/game_tracker/game_tracker.gd`
- Create: `core/tests/test_game_tracker_init.gd`

**Step 1: Write the failing test for init()**

Create `core/tests/test_game_tracker_init.gd`:

```gdscript
extends GutTest

var tracker: Node

func before_each():
	tracker = load("res://addons/game_tracker/game_tracker.gd").new()
	add_child(tracker)

func after_each():
	tracker.queue_free()

func test_init_stores_config():
	tracker.init({
		"endpoint": "https://alloy.example.com",
		"game": "test-game",
		"version": "1.0.0",
		"environment": "test"
	})

	assert_eq(tracker._config.endpoint, "https://alloy.example.com")
	assert_eq(tracker._config.game, "test-game")
	assert_eq(tracker._config.version, "1.0.0")
	assert_eq(tracker._config.environment, "test")

func test_init_generates_session_id():
	tracker.init({"endpoint": "https://example.com", "game": "test"})

	assert_ne(tracker._session_id, "", "Session ID should be generated")
	assert_true(tracker._session_id.length() > 10, "Session ID should be substantial")

func test_init_collects_device_context():
	tracker.init({"endpoint": "https://example.com", "game": "test"})

	assert_true(tracker._device_context.has("os"))
	assert_true(tracker._device_context.has("godot_version"))
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - cannot load game_tracker.gd

**Step 3: Create plugin.cfg**

Create `addons/game_tracker/plugin.cfg`:

```ini
[plugin]

name="GameTracker"
description="Observability addon for LGTM stack via Grafana Alloy"
author="Your Name"
version="1.0.0"
script="game_tracker.gd"
```

**Step 4: Write minimal implementation**

Create `addons/game_tracker/game_tracker.gd`:

```gdscript
extends Node

# Constants
const MAX_QUEUE_SIZE := 100
const FLUSH_INTERVAL := 5.0
const FLUSH_THRESHOLD := 20

# Config storage
var _config := {}
var _session_id := ""
var _device_context := {}

# User-set context
var _user := {}
var _contexts := {}
var _tags := {}

# Queues
var _log_queue := []
var _metric_queue := []
var _trace_queue := []

# HTTP state
var _http_request: HTTPRequest
var _request_in_flight := false
var _flush_timer: Timer

func _ready():
	_setup_http()
	_setup_timer()

func _setup_http():
	_http_request = HTTPRequest.new()
	_http_request.timeout = 10.0
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

func _setup_timer():
	_flush_timer = Timer.new()
	_flush_timer.wait_time = FLUSH_INTERVAL
	_flush_timer.autostart = false
	add_child(_flush_timer)
	_flush_timer.timeout.connect(_on_flush_timer)

func init(config: Dictionary):
	_config = {
		"endpoint": config.get("endpoint", ""),
		"game": config.get("game", "unknown"),
		"version": config.get("version", "0.0.0"),
		"environment": config.get("environment", "development"),
		"max_breadcrumbs": config.get("max_breadcrumbs", 50),
	}
	_session_id = _generate_session_id()
	_device_context = _collect_device_context()
	_flush_timer.start()

func _generate_session_id() -> String:
	var uuid = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		uuid += "0123456789abcdef"[randi() % 16]
	return uuid

func _collect_device_context() -> Dictionary:
	return {
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"locale": OS.get_locale(),
		"godot_version": Engine.get_version_info().string,
		"gpu": RenderingServer.get_video_adapter_name(),
		"screen": "%dx%d" % [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
	}

func _on_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	_request_in_flight = false

func _on_flush_timer():
	_flush_all()

func _flush_all():
	pass  # Implemented in later tasks
```

**Step 5: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 6: Commit**

```bash
git add addons/game_tracker/ core/tests/test_game_tracker_init.gd
git commit -m "feat(game_tracker): add addon structure and init()"
```

---

## Task 2: Implement Context Setters

**Files:**
- Modify: `addons/game_tracker/game_tracker.gd`
- Modify: `core/tests/test_game_tracker_init.gd`

**Step 1: Write failing tests for context setters**

Add to `core/tests/test_game_tracker_init.gd`:

```gdscript
func test_set_user():
	tracker.init({"endpoint": "https://example.com", "game": "test"})
	tracker.set_user({"id": "player_123", "tier": "premium"})

	assert_eq(tracker._user.id, "player_123")
	assert_eq(tracker._user.tier, "premium")

func test_set_context():
	tracker.init({"endpoint": "https://example.com", "game": "test"})
	tracker.set_context("player", {"health": 100, "level": 5})

	assert_eq(tracker._contexts.player.health, 100)
	assert_eq(tracker._contexts.player.level, 5)

func test_set_tag():
	tracker.init({"endpoint": "https://example.com", "game": "test"})
	tracker.set_tag("build", "demo")
	tracker.set_tag("region", "us-west")

	assert_eq(tracker._tags.build, "demo")
	assert_eq(tracker._tags.region, "us-west")
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - methods not defined

**Step 3: Implement context setters**

Add to `addons/game_tracker/game_tracker.gd` (after `init` function):

```gdscript
func set_user(user_data: Dictionary):
	_user = user_data

func set_context(name: String, data: Dictionary):
	_contexts[name] = data

func set_tag(key: String, value: String):
	_tags[key] = value
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add addons/game_tracker/game_tracker.gd core/tests/test_game_tracker_init.gd
git commit -m "feat(game_tracker): add context setters (set_user, set_context, set_tag)"
```

---

## Task 3: Implement Logging API

**Files:**
- Modify: `addons/game_tracker/game_tracker.gd`
- Create: `core/tests/test_game_tracker_logging.gd`

**Step 1: Write failing tests for logging**

Create `core/tests/test_game_tracker_logging.gd`:

```gdscript
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
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - log_info not defined

**Step 3: Implement logging methods**

Add to `addons/game_tracker/game_tracker.gd`:

```gdscript
func log_info(message: String, data: Dictionary = {}):
	_queue_log("info", message, data)

func log_warn(message: String, data: Dictionary = {}):
	_queue_log("warn", message, data)

func log_error(message: String, data: Dictionary = {}):
	_queue_log("error", message, data)

func log_debug(message: String, data: Dictionary = {}):
	_queue_log("debug", message, data)

func _queue_log(level: String, message: String, data: Dictionary):
	if _log_queue.size() >= MAX_QUEUE_SIZE:
		_log_queue.pop_front()
	_log_queue.append({
		"level": level,
		"msg": message,
		"data": data,
		"ts": Time.get_unix_time_from_system()
	})
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add addons/game_tracker/game_tracker.gd core/tests/test_game_tracker_logging.gd
git commit -m "feat(game_tracker): add logging API (log_info, log_warn, log_error, log_debug)"
```

---

## Task 4: Implement Metrics API

**Files:**
- Modify: `addons/game_tracker/game_tracker.gd`
- Create: `core/tests/test_game_tracker_metrics.gd`

**Step 1: Write failing tests for metrics**

Create `core/tests/test_game_tracker_metrics.gd`:

```gdscript
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
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - increment not defined

**Step 3: Implement metrics methods**

Add to `addons/game_tracker/game_tracker.gd`:

```gdscript
func increment(name: String, labels: Dictionary = {}, amount: int = 1):
	_queue_metric("counter", name, amount, labels)

func gauge(name: String, value: float, labels: Dictionary = {}):
	_queue_metric("gauge", name, value, labels)

func histogram(name: String, value: float, labels: Dictionary = {}):
	_queue_metric("histogram", name, value, labels)

func _queue_metric(type: String, name: String, value: float, labels: Dictionary):
	if _metric_queue.size() >= MAX_QUEUE_SIZE:
		_metric_queue.pop_front()
	_metric_queue.append({
		"type": type,
		"name": name,
		"value": value,
		"labels": labels,
		"ts": Time.get_unix_time_from_system()
	})
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add addons/game_tracker/game_tracker.gd core/tests/test_game_tracker_metrics.gd
git commit -m "feat(game_tracker): add metrics API (increment, gauge, histogram)"
```

---

## Task 5: Implement Tracing API (Span Class)

**Files:**
- Modify: `addons/game_tracker/game_tracker.gd`
- Create: `core/tests/test_game_tracker_tracing.gd`

**Step 1: Write failing tests for tracing**

Create `core/tests/test_game_tracker_tracing.gd`:

```gdscript
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
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - start_span not defined

**Step 3: Implement Span class and tracing methods**

Add to `addons/game_tracker/game_tracker.gd` (at the top, after extends):

```gdscript
class Span:
	var tracker: Node
	var name: String
	var trace_id: String
	var span_id: String
	var parent_span_id: String
	var start_time: int
	var attributes: Dictionary

	func _init(p_tracker: Node, p_name: String, p_attrs: Dictionary, p_trace_id: String, p_span_id: String, p_parent_span_id: String):
		tracker = p_tracker
		name = p_name
		attributes = p_attrs
		trace_id = p_trace_id
		span_id = p_span_id
		parent_span_id = p_parent_span_id
		start_time = Time.get_ticks_usec()

	func end():
		var end_time = Time.get_ticks_usec()
		tracker._queue_trace(self, end_time)
```

Add these methods to the main class:

```gdscript
func start_span(name: String, attributes: Dictionary = {}, parent: Span = null) -> Span:
	var trace_id: String
	var parent_span_id: String

	if parent:
		trace_id = parent.trace_id
		parent_span_id = parent.span_id
	else:
		trace_id = _generate_trace_id()
		parent_span_id = ""

	var span_id = _generate_span_id()
	return Span.new(self, name, attributes, trace_id, span_id, parent_span_id)

func _generate_trace_id() -> String:
	var id = ""
	for i in range(32):
		id += "0123456789abcdef"[randi() % 16]
	return id

func _generate_span_id() -> String:
	var id = ""
	for i in range(16):
		id += "0123456789abcdef"[randi() % 16]
	return id

func _queue_trace(span: Span, end_time: int):
	if _trace_queue.size() >= MAX_QUEUE_SIZE:
		_trace_queue.pop_front()
	_trace_queue.append({
		"name": span.name,
		"trace_id": span.trace_id,
		"span_id": span.span_id,
		"parent_span_id": span.parent_span_id,
		"start_time": span.start_time,
		"end_time": end_time,
		"attributes": span.attributes
	})
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add addons/game_tracker/game_tracker.gd core/tests/test_game_tracker_tracing.gd
git commit -m "feat(game_tracker): add tracing API (start_span, Span.end)"
```

---

## Task 6: Implement Loki Log Formatting

**Files:**
- Modify: `addons/game_tracker/game_tracker.gd`
- Create: `core/tests/test_game_tracker_formats.gd`

**Step 1: Write failing test for Loki format**

Create `core/tests/test_game_tracker_formats.gd`:

```gdscript
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
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - _format_loki_payload not defined

**Step 3: Implement Loki formatting**

Add to `addons/game_tracker/game_tracker.gd`:

```gdscript
func _format_loki_payload() -> Dictionary:
	# Group logs by level
	var streams_by_level := {}

	for log_entry in _log_queue:
		var level = log_entry.level
		if not streams_by_level.has(level):
			streams_by_level[level] = []

		var ts_ns = str(int(log_entry.ts * 1_000_000_000))
		var log_data = {
			"msg": log_entry.msg,
			"data": log_entry.data,
			"session_id": _session_id,
			"user": _user,
			"contexts": _contexts,
			"tags": _tags,
			"device": _device_context
		}
		streams_by_level[level].append([ts_ns, JSON.stringify(log_data)])

	var streams := []
	for level in streams_by_level:
		streams.append({
			"stream": {
				"game": _config.game,
				"env": _config.environment,
				"version": _config.version,
				"level": level
			},
			"values": streams_by_level[level]
		})

	return {"streams": streams}
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add addons/game_tracker/game_tracker.gd core/tests/test_game_tracker_formats.gd
git commit -m "feat(game_tracker): add Loki log formatting"
```

---

## Task 7: Implement Prometheus Metrics Formatting

**Files:**
- Modify: `addons/game_tracker/game_tracker.gd`
- Modify: `core/tests/test_game_tracker_formats.gd`

**Step 1: Write failing test for Prometheus format**

Add to `core/tests/test_game_tracker_formats.gd`:

```gdscript
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
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - _format_prometheus_payload not defined

**Step 3: Implement Prometheus formatting**

Add to `addons/game_tracker/game_tracker.gd`:

```gdscript
func _format_prometheus_payload() -> Dictionary:
	var timeseries := []

	for metric in _metric_queue:
		var metric_name = metric.name
		if metric.type == "counter":
			metric_name += "_total"

		var labels := [
			{"name": "__name__", "value": metric_name},
			{"name": "game", "value": _config.game},
			{"name": "env", "value": _config.environment},
			{"name": "version", "value": _config.version},
		]

		for key in metric.labels:
			labels.append({"name": key, "value": str(metric.labels[key])})

		var ts_ms = int(metric.ts * 1000)
		timeseries.append({
			"labels": labels,
			"samples": [{"value": metric.value, "timestamp": ts_ms}]
		})

	return {"timeseries": timeseries}
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add addons/game_tracker/game_tracker.gd core/tests/test_game_tracker_formats.gd
git commit -m "feat(game_tracker): add Prometheus metrics formatting"
```

---

## Task 8: Implement OTLP Trace Formatting

**Files:**
- Modify: `addons/game_tracker/game_tracker.gd`
- Modify: `core/tests/test_game_tracker_formats.gd`

**Step 1: Write failing test for OTLP format**

Add to `core/tests/test_game_tracker_formats.gd`:

```gdscript
func test_format_otlp_payload():
	var span = tracker.start_span("test_op", {"key": "value"})
	span.end()

	var payload = tracker._format_otlp_payload()

	assert_true(payload.has("resourceSpans"))
	assert_eq(payload.resourceSpans.size(), 1)

	var resource_span = payload.resourceSpans[0]
	assert_true(resource_span.has("resource"))
	assert_true(resource_span.has("scopeSpans"))

func test_otlp_resource_attributes():
	var span = tracker.start_span("test_op")
	span.end()

	var payload = tracker._format_otlp_payload()
	var attrs = payload.resourceSpans[0].resource.attributes

	var attr_keys = []
	for attr in attrs:
		attr_keys.append(attr.key)

	assert_true("service.name" in attr_keys)
	assert_true("service.version" in attr_keys)

func test_otlp_span_structure():
	var span = tracker.start_span("level_load", {"level": "forest"})
	span.end()

	var payload = tracker._format_otlp_payload()
	var otlp_span = payload.resourceSpans[0].scopeSpans[0].spans[0]

	assert_eq(otlp_span.name, "level_load")
	assert_true(otlp_span.has("traceId"))
	assert_true(otlp_span.has("spanId"))
	assert_true(otlp_span.has("startTimeUnixNano"))
	assert_true(otlp_span.has("endTimeUnixNano"))
	assert_true(otlp_span.has("attributes"))

func test_otlp_nested_spans():
	var parent = tracker.start_span("parent")
	var child = tracker.start_span("child", {}, parent)
	child.end()
	parent.end()

	var payload = tracker._format_otlp_payload()
	var spans = payload.resourceSpans[0].scopeSpans[0].spans

	assert_eq(spans.size(), 2)

	# Find child span and verify parentSpanId
	var child_span = null
	for s in spans:
		if s.name == "child":
			child_span = s
			break

	assert_not_null(child_span)
	assert_true(child_span.has("parentSpanId"))
	assert_ne(child_span.parentSpanId, "")
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - _format_otlp_payload not defined

**Step 3: Implement OTLP formatting**

Add to `addons/game_tracker/game_tracker.gd`:

```gdscript
func _format_otlp_payload() -> Dictionary:
	var spans := []

	for trace in _trace_queue:
		var attributes := []
		for key in trace.attributes:
			attributes.append({
				"key": key,
				"value": {"stringValue": str(trace.attributes[key])}
			})

		var span_data := {
			"traceId": trace.trace_id,
			"spanId": trace.span_id,
			"name": trace.name,
			"startTimeUnixNano": str(trace.start_time * 1000),  # usec to nsec
			"endTimeUnixNano": str(trace.end_time * 1000),
			"attributes": attributes
		}

		if trace.parent_span_id != "":
			span_data["parentSpanId"] = trace.parent_span_id

		spans.append(span_data)

	return {
		"resourceSpans": [{
			"resource": {
				"attributes": [
					{"key": "service.name", "value": {"stringValue": _config.game}},
					{"key": "service.version", "value": {"stringValue": _config.version}},
					{"key": "deployment.environment", "value": {"stringValue": _config.environment}},
					{"key": "session.id", "value": {"stringValue": _session_id}}
				]
			},
			"scopeSpans": [{
				"scope": {"name": "game_tracker", "version": "1.0.0"},
				"spans": spans
			}]
		}]
	}
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add addons/game_tracker/game_tracker.gd core/tests/test_game_tracker_formats.gd
git commit -m "feat(game_tracker): add OTLP trace formatting"
```

---

## Task 9: Implement HTTP Flush Logic

**Files:**
- Modify: `addons/game_tracker/game_tracker.gd`
- Create: `core/tests/test_game_tracker_flush.gd`

**Step 1: Write failing tests for flush behavior**

Create `core/tests/test_game_tracker_flush.gd`:

```gdscript
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
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - _flush_logs not defined

**Step 3: Implement flush methods**

Replace the empty `_flush_all` and add flush methods in `addons/game_tracker/game_tracker.gd`:

```gdscript
func _flush_all():
	_flush_logs()
	_flush_metrics()
	_flush_traces()

func _flush_logs():
	if _log_queue.is_empty():
		return
	if _config.endpoint == "":
		_log_queue.clear()
		return

	var payload = _format_loki_payload()
	_send_async(_config.endpoint + "/loki/api/v1/push", payload)
	_log_queue.clear()

func _flush_metrics():
	if _metric_queue.is_empty():
		return
	if _config.endpoint == "":
		_metric_queue.clear()
		return

	var payload = _format_prometheus_payload()
	_send_async(_config.endpoint + "/api/v1/push", payload)
	_metric_queue.clear()

func _flush_traces():
	if _trace_queue.is_empty():
		return
	if _config.endpoint == "":
		_trace_queue.clear()
		return

	var payload = _format_otlp_payload()
	_send_async(_config.endpoint + "/v1/traces", payload)
	_trace_queue.clear()

func _send_async(url: String, payload: Dictionary):
	if _request_in_flight:
		return  # Skip if previous request still pending

	var json = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]

	_request_in_flight = true
	var error = _http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	if error != OK:
		_request_in_flight = false  # Reset on immediate failure
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add addons/game_tracker/game_tracker.gd core/tests/test_game_tracker_flush.gd
git commit -m "feat(game_tracker): add HTTP flush logic"
```

---

## Task 10: Final Assembly and Manual Testing

**Files:**
- Modify: `addons/game_tracker/game_tracker.gd` (if needed)
- No new tests (manual verification)

**Step 1: Verify all tests pass**

Run: `just test`
Expected: All tests PASS

**Step 2: Review the complete game_tracker.gd file**

Read through the file to ensure:
- All methods are implemented
- No duplicate code
- Proper ordering (class Span at top, constants, vars, _ready, public methods, private methods)

**Step 3: Create a simple test scene (optional manual test)**

If you have a local Alloy instance, you can test manually:

```gdscript
# In any test scene
func _ready():
	GameTracker.init({
		"endpoint": "http://localhost:4318",  # Alloy OTLP endpoint
		"game": "test-game",
		"version": "1.0.0",
		"environment": "development"
	})

	GameTracker.set_user({"id": "test_user"})
	GameTracker.log_info("Game started")
	GameTracker.increment("game_starts")

	var span = GameTracker.start_span("startup")
	await get_tree().create_timer(0.1).timeout
	span.end()
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(game_tracker): complete GameTracker addon v1.0.0"
```

---

## Summary

| Task | Description | Tests |
|------|-------------|-------|
| 1 | Addon structure + init() | 3 |
| 2 | Context setters | 3 |
| 3 | Logging API | 6 |
| 4 | Metrics API | 6 |
| 5 | Tracing API (Span) | 5 |
| 6 | Loki formatting | 3 |
| 7 | Prometheus formatting | 3 |
| 8 | OTLP formatting | 4 |
| 9 | HTTP flush logic | 5 |
| 10 | Final assembly | - |

**Total: 38 tests across 10 tasks**

After completing all tasks, you'll have a fully functional GameTracker addon that:
- Queues logs, metrics, and traces
- Formats them for Loki, Prometheus, and OTLP
- Sends them to Grafana Alloy in batched, fire-and-forget HTTP requests
- Can be copied to any Godot 4 project
