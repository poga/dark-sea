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
