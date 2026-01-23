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
