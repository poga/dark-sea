extends GutTest

var item: Area2D

func before_each():
	item = preload("res://scenes/item/item.tscn").instantiate()
	add_child_autofree(item)

func test_initial_state_is_pickup():
	assert_eq(item.current_state, item.State.PICKUP)
	assert_true(item.get_node("PickupState").visible)
	assert_false(item.get_node("ActiveState").visible)

func test_item_name_sets_labels():
	assert_eq(item.get_node("PickupState/Label").text, "Item")
	assert_eq(item.get_node("ActiveState/Label").text, "Item")

func test_pick_up_from_pickup_emits_picked_up():
	watch_signals(item)
	item.pick_up()
	assert_signal_emitted(item, "picked_up")

func test_activate_switches_to_active_state():
	item.activate()
	assert_eq(item.current_state, item.State.ACTIVE)
	assert_false(item.get_node("PickupState").visible)
	assert_true(item.get_node("ActiveState").visible)

func test_activate_emits_activated():
	watch_signals(item)
	item.activate()
	assert_signal_emitted(item, "activated")

func test_pick_up_from_active_emits_deactivated():
	item.activate()
	watch_signals(item)
	item.pick_up()
	assert_signal_emitted(item, "deactivated")

func test_pick_up_from_active_returns_to_pickup_state():
	item.activate()
	item.pick_up()
	assert_eq(item.current_state, item.State.PICKUP)
	assert_true(item.get_node("PickupState").visible)
	assert_false(item.get_node("ActiveState").visible)

func test_store_in_inventory_sets_inventory_state():
	item.store_in_inventory()
	assert_eq(item.current_state, item.State.INVENTORY)

func test_store_in_inventory_shows_inventory_state_node():
	item.store_in_inventory()
	assert_true(item.get_node("InventoryState").visible)
	assert_false(item.get_node("PickupState").visible)
	assert_false(item.get_node("ActiveState").visible)

func test_use_result_enum_exists():
	assert_eq(item.UseResult.NOTHING, 0)
	assert_eq(item.UseResult.KEEP, 1)
	assert_eq(item.UseResult.CONSUME, 2)
	assert_eq(item.UseResult.PLACE, 3)

func test_can_use_returns_true_by_default():
	assert_true(item.can_use({}))

func test_use_returns_consume_by_default():
	assert_eq(item.use({}), item.UseResult.CONSUME)

func test_has_preview_returns_false_by_default():
	assert_false(item.has_preview())

func test_get_preview_position_returns_target():
	var ctx: Dictionary = {"target_position": Vector2(100, 200)}
	assert_eq(item.get_preview_position(ctx), Vector2(100, 200))
