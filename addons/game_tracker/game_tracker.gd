extends Node

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

func set_user(user_data: Dictionary):
	_user = user_data

func set_context(name: String, data: Dictionary):
	_contexts[name] = data

func set_tag(key: String, value: String):
	_tags[key] = value

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

func start_span(span_name: String, attributes: Dictionary = {}, parent: Span = null) -> Span:
	var trace_id: String
	var parent_span_id: String

	if parent:
		trace_id = parent.trace_id
		parent_span_id = parent.span_id
	else:
		trace_id = _generate_trace_id()
		parent_span_id = ""

	var span_id = _generate_span_id()
	return Span.new(self, span_name, attributes, trace_id, span_id, parent_span_id)

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
