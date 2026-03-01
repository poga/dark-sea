extends GutTest

var item: Area2D

func before_each():
	item = preload("res://scenes/item/item.tscn").instantiate()
	add_child_autofree(item)

func test_is_swinging_false_by_default():
	assert_false(item.is_swinging)

func test_swing_duration_default():
	assert_eq(item.swing_duration, 0.3)

func test_swing_angle_default():
	assert_eq(item.swing_angle, 45.0)

func test_play_swing_sets_is_swinging():
	var called := false
	item.play_swing(Vector2.RIGHT, func(): called = true)
	assert_true(item.is_swinging)

func test_play_swing_creates_valid_tween():
	item.play_swing(Vector2.RIGHT, func(): pass)
	assert_not_null(item._swing_tween)
	assert_true(item._swing_tween.is_valid())
