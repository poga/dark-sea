extends GutTest

var item: Area2D
var player: CharacterBody2D

func before_each():
	item = preload("res://scenes/item/item.tscn").instantiate()
	add_child_autofree(item)

func test_is_swinging_false_by_default():
	assert_false(item.is_swinging)

func test_swing_duration_default():
	assert_eq(item.swing_duration, 0.1)

func test_swing_distance_default():
	assert_eq(item.swing_distance, 60.0)

func test_play_swing_sets_is_swinging():
	var called := false
	item.play_swing(Vector2.RIGHT, func(): called = true)
	assert_true(item.is_swinging)

func test_play_swing_creates_valid_tween():
	item.play_swing(Vector2.RIGHT, func(): pass)
	assert_not_null(item._swing_tween)
	assert_true(item._swing_tween.is_valid())

func _setup_player_and_item() -> Area2D:
	GameManager.reset_inventory()
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	GameManager.register_player(player)
	var held: Area2D = preload("res://scenes/item/item.tscn").instantiate()
	add_child_autofree(held)
	GameManager.try_pickup(held)
	return held

func test_use_active_item_blocked_during_swing():
	var held: Area2D = _setup_player_and_item()
	held.is_swinging = true
	watch_signals(GameManager)
	GameManager.use_active_item(Vector2(100, 0))
	assert_signal_not_emitted(GameManager, "item_use_attempted")

func test_use_active_item_starts_swing():
	var held: Area2D = _setup_player_and_item()
	GameManager.use_active_item(Vector2(100, 0))
	assert_true(held.is_swinging)
