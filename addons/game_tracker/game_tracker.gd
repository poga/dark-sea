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
	pass  # Implemented in later tasks

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
