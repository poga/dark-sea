extends GutTest

var player: CharacterBody2D
var item_scene: PackedScene = preload("res://scenes/item/item.tscn")

func before_each():
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)

func _make_item(pos: Vector2) -> Area2D:
	var item: Area2D = item_scene.instantiate()
	add_child_autofree(item)
	item.global_position = pos
	return item

func _pick_up_item(item: Area2D) -> void:
	player._items_in_range.append(item)
	player.pick_up_nearest_item()

# --- Inventory initialization ---

func test_inventory_has_8_slots():
	assert_eq(player.inventory.size(), 8)

func test_inventory_initially_all_null():
	for slot in player.inventory:
		assert_null(slot)

func test_active_slot_initially_zero():
	assert_eq(player.active_slot, 0)

# --- Pickup ---

func test_get_nearest_item_returns_null_when_empty():
	assert_null(player.get_nearest_item())

func test_get_nearest_item_returns_closest():
	var far_item: Area2D = _make_item(Vector2(200, 0))
	var near_item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(far_item)
	player._items_in_range.append(near_item)
	assert_eq(player.get_nearest_item(), near_item)

func test_pick_up_stores_in_first_empty_slot():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	assert_eq(player.inventory[0], item)

func test_pick_up_second_item_uses_slot_1():
	var item1: Area2D = _make_item(Vector2(30, 0))
	var item2: Area2D = _make_item(Vector2(40, 0))
	_pick_up_item(item1)
	_pick_up_item(item2)
	assert_eq(player.inventory[0], item1)
	assert_eq(player.inventory[1], item2)

func test_pick_up_emits_inventory_changed():
	var item: Area2D = _make_item(Vector2(30, 0))
	watch_signals(player)
	_pick_up_item(item)
	assert_signal_emitted(player, "inventory_changed")

func test_pick_up_emits_item_picked_up():
	var item: Area2D = _make_item(Vector2(30, 0))
	watch_signals(player)
	_pick_up_item(item)
	assert_signal_emitted(player, "item_picked_up")

func test_pick_up_active_slot_reparents_to_hold_position():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	assert_eq(item.get_parent(), player.get_node("HoldPosition"))

func test_pick_up_non_active_slot_removes_from_tree():
	# Fill slot 0 first, then pick up into slot 1
	var item1: Area2D = _make_item(Vector2(30, 0))
	var item2: Area2D = _make_item(Vector2(40, 0))
	_pick_up_item(item1)
	_pick_up_item(item2)
	# item2 is in slot 1, active_slot is 0, so item2 should not be in tree
	assert_null(item2.get_parent())

func test_pick_up_sets_item_to_inventory_state():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	assert_eq(item.current_state, item.State.INVENTORY)

func test_pick_up_blocked_when_inventory_full():
	# Fill all 8 slots
	for i in range(8):
		var item: Area2D = _make_item(Vector2(30 + i * 10, 0))
		_pick_up_item(item)
	# 9th item should not be picked up
	var extra: Area2D = _make_item(Vector2(200, 0))
	player._items_in_range.append(extra)
	player.pick_up_nearest_item()
	assert_false(player.inventory.has(extra))

func test_pick_up_removes_from_items_in_range():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(item)
	player.pick_up_nearest_item()
	assert_false(player._items_in_range.has(item))

func test_pick_up_does_nothing_when_no_items():
	player.pick_up_nearest_item()
	for slot in player.inventory:
		assert_null(slot)

func test_pick_up_while_holding_stores_in_next_empty_slot():
	var item1: Area2D = _make_item(Vector2(30, 0))
	var item2: Area2D = _make_item(Vector2(40, 0))
	_pick_up_item(item1)
	# item1 is in slot 0 (active). Now pick up item2 — should go to slot 1.
	_pick_up_item(item2)
	assert_eq(player.inventory[0], item1)
	assert_eq(player.inventory[1], item2)
	# item1 should still be at HoldPosition (active slot unchanged)
	assert_eq(item1.get_parent(), player.get_node("HoldPosition"))

# --- Drop ---

func test_drop_clears_active_slot():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	player.drop_item()
	assert_null(player.inventory[0])

func test_drop_emits_inventory_changed():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	watch_signals(player)
	player.drop_item()
	assert_signal_emitted(player, "inventory_changed")

func test_drop_emits_item_dropped():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	watch_signals(player)
	player.drop_item()
	assert_signal_emitted(player, "item_dropped")

func test_drop_reparents_to_world():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	player.drop_item()
	assert_eq(item.get_parent(), player.get_parent())

func test_has_active_item_true_when_holding():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	assert_true(player.has_active_item())

func test_has_active_item_false_when_empty():
	assert_false(player.has_active_item())

# --- Slot switching ---

func test_switch_slot_changes_active_slot():
	player.switch_to_slot(3)
	assert_eq(player.active_slot, 3)

func test_switch_slot_emits_active_slot_changed():
	watch_signals(player)
	player.switch_to_slot(3)
	assert_signal_emitted(player, "active_slot_changed")

func test_switch_slot_shows_new_item_at_hold_position():
	var item1: Area2D = _make_item(Vector2(30, 0))
	var item2: Area2D = _make_item(Vector2(40, 0))
	_pick_up_item(item1)
	_pick_up_item(item2)
	player.switch_to_slot(1)
	assert_eq(item2.get_parent(), player.get_node("HoldPosition"))

func test_switch_slot_removes_old_item_from_tree():
	var item1: Area2D = _make_item(Vector2(30, 0))
	var item2: Area2D = _make_item(Vector2(40, 0))
	_pick_up_item(item1)
	_pick_up_item(item2)
	player.switch_to_slot(1)
	assert_null(item1.get_parent())

func test_switch_slot_same_slot_does_nothing():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	player.switch_to_slot(0)
	assert_eq(item.get_parent(), player.get_node("HoldPosition"))

func test_switch_next_wraps_around():
	player.switch_to_slot(7)
	player.switch_next()
	assert_eq(player.active_slot, 0)

func test_switch_prev_wraps_around():
	player.switch_prev()
	assert_eq(player.active_slot, 7)

# --- Auto-pickup helpers ---

func _simulate_item_enters_range(item: Area2D) -> void:
	player._on_pickup_zone_area_entered(item)

# --- Auto-pickup ---

func test_auto_pickup_on_entering_range():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	assert_eq(player.inventory[0], item)

func test_auto_pickup_emits_item_picked_up():
	var item: Area2D = _make_item(Vector2(30, 0))
	watch_signals(player)
	_simulate_item_enters_range(item)
	assert_signal_emitted(player, "item_picked_up")

func test_auto_pickup_ignored_when_inventory_full():
	for i in range(8):
		var item: Area2D = _make_item(Vector2(30 + i * 10, 0))
		_simulate_item_enters_range(item)
	var extra: Area2D = _make_item(Vector2(200, 0))
	_simulate_item_enters_range(extra)
	assert_false(player.inventory.has(extra))
	# extra should remain in _items_in_range for later pickup
	assert_true(player._items_in_range.has(extra))
