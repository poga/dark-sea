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
