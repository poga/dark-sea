extends Control

@onready var endpoint_input: LineEdit = $VBoxContainer/EndpointRow/EndpointInput
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var log_output: TextEdit = $VBoxContainer/LogOutput

var _initialized := false
var _active_span = null

func _ready():
	endpoint_input.text = "http://localhost:4318"
	_log("GameTracker Demo ready. Enter your Alloy endpoint and click Initialize.")

func _log(message: String):
	var timestamp = Time.get_time_string_from_system()
	log_output.text += "[%s] %s\n" % [timestamp, message]
	log_output.scroll_vertical = log_output.get_line_count()

func _on_init_pressed():
	var endpoint = endpoint_input.text.strip_edges()
	if endpoint.is_empty():
		_log("ERROR: Endpoint cannot be empty")
		return

	GameTracker.init({
		"endpoint": endpoint,
		"game": "tracker-demo",
		"version": "1.0.0",
		"environment": "development"
	})
	GameTracker.set_user({"id": "demo_user", "tier": "tester"})
	GameTracker.set_tag("demo", "true")

	_initialized = true
	status_label.text = "Status: Initialized (%s)" % endpoint
	status_label.add_theme_color_override("font_color", Color.GREEN)
	_log("Initialized with endpoint: %s" % endpoint)

func _check_init() -> bool:
	if not _initialized:
		_log("ERROR: Call Initialize first!")
		return false
	return true

# Logging buttons
func _on_log_info_pressed():
	if not _check_init(): return
	GameTracker.log_info("User clicked info button", {"button": "log_info", "timestamp": Time.get_unix_time_from_system()})
	_log("Sent: log_info")

func _on_log_warn_pressed():
	if not _check_init(): return
	GameTracker.log_warn("Demo warning triggered", {"severity": "medium"})
	_log("Sent: log_warn")

func _on_log_error_pressed():
	if not _check_init(): return
	GameTracker.log_error("Demo error occurred", {"error_code": 500, "recoverable": true})
	_log("Sent: log_error")

func _on_log_debug_pressed():
	if not _check_init(): return
	GameTracker.log_debug("Debug information", {"memory_mb": OS.get_static_memory_usage() / 1024 / 1024})
	_log("Sent: log_debug")

# Metrics buttons
func _on_increment_pressed():
	if not _check_init(): return
	GameTracker.increment("demo_button_clicks", {"button": "increment"})
	_log("Sent: increment(demo_button_clicks)")

func _on_increment_10_pressed():
	if not _check_init(): return
	GameTracker.increment("demo_points_earned", {"source": "bonus"}, 10)
	_log("Sent: increment(demo_points_earned, 10)")

func _on_gauge_pressed():
	if not _check_init(): return
	var random_health = randi_range(0, 100)
	GameTracker.gauge("demo_player_health", random_health, {"player": "demo"})
	_log("Sent: gauge(demo_player_health, %d)" % random_health)

func _on_histogram_pressed():
	if not _check_init(): return
	var random_latency = randf_range(10, 500)
	GameTracker.histogram("demo_response_time_ms", random_latency, {"endpoint": "/api/test"})
	_log("Sent: histogram(demo_response_time_ms, %.1f)" % random_latency)

# Tracing buttons
func _on_start_span_pressed():
	if not _check_init(): return
	if _active_span != null:
		_log("ERROR: Span already active. End it first.")
		return
	_active_span = GameTracker.start_span("demo_operation", {"triggered_by": "button"})
	_log("Started span: demo_operation (click End Span to complete)")

func _on_end_span_pressed():
	if not _check_init(): return
	if _active_span == null:
		_log("ERROR: No active span. Start one first.")
		return
	_active_span.end()
	_active_span = null
	_log("Ended span: demo_operation")

func _on_quick_span_pressed():
	if not _check_init(): return
	var span = GameTracker.start_span("quick_operation", {"type": "instant"})
	# Simulate some work
	await get_tree().create_timer(0.1).timeout
	span.end()
	_log("Sent: quick span (100ms duration)")

# Context buttons
func _on_set_user_pressed():
	if not _check_init(): return
	var user_id = "user_%d" % randi_range(1000, 9999)
	GameTracker.set_user({"id": user_id, "tier": "premium", "registered": true})
	_log("Set user: %s" % user_id)

func _on_set_context_pressed():
	if not _check_init(): return
	GameTracker.set_context("game_state", {
		"level": randi_range(1, 50),
		"score": randi_range(0, 10000),
		"lives": randi_range(0, 3)
	})
	_log("Set context: game_state")

func _on_set_tag_pressed():
	if not _check_init(): return
	var tags = ["alpha", "beta", "release", "hotfix"]
	var tag = tags[randi() % tags.size()]
	GameTracker.set_tag("build_type", tag)
	_log("Set tag: build_type = %s" % tag)

func _on_clear_log_pressed():
	log_output.text = ""
