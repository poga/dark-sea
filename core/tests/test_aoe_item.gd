extends GutTest

var item: Area2D

func before_each():
	item = preload("res://scenes/item/aoe_item.tscn").instantiate()
	add_child_autofree(item)

func test_inherits_base_item_state():
	assert_eq(item.current_state, item.State.PICKUP)

func test_has_custom_export():
	assert_true(item.explosion_radius > 0)

func test_inherits_turret_exports():
	assert_eq(item.attack_range, 150.0)
	assert_eq(item.attack_rate, 1.0)

func test_activate_enables_turret():
	item.activate()
	assert_eq(item.current_state, item.State.ACTIVE)
	var detection: Area2D = item.get_node("ActiveState/DetectionArea")
	assert_true(detection.monitoring)

func test_pick_up_deactivates_turret():
	item.activate()
	item.pick_up()
	assert_eq(item.current_state, item.State.PICKUP)
