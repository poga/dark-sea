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

# --- Inventory initialization ---

func test_inventory_has_8_slots():
	assert_eq(player.inventory.size(), 8)

func test_inventory_initially_all_null():
	for slot in player.inventory:
		assert_null(slot)

func test_active_slot_initially_zero():
	assert_eq(player.active_slot, 0)

# --- Pickup ---

func test_pick_up_stores_in_first_empty_slot():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	assert_eq(player.inventory[0], item)

func test_pick_up_second_item_uses_slot_1():
	var item1: Area2D = _make_item(Vector2(30, 0))
	var item2: Area2D = _make_item(Vector2(40, 0))
	_simulate_item_enters_range(item1)
	_simulate_item_enters_range(item2)
	assert_eq(player.inventory[0], item1)
	assert_eq(player.inventory[1], item2)

func test_pick_up_emits_inventory_changed():
	var item: Area2D = _make_item(Vector2(30, 0))
	watch_signals(player)
	_simulate_item_enters_range(item)
	assert_signal_emitted(player, "inventory_changed")

func test_pick_up_emits_item_picked_up():
	var item: Area2D = _make_item(Vector2(30, 0))
	watch_signals(player)
	_simulate_item_enters_range(item)
	assert_signal_emitted(player, "item_picked_up")

func test_pick_up_active_slot_reparents_to_hold_position():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	assert_eq(item.get_parent(), player.get_node("HoldPosition"))

func test_pick_up_non_active_slot_removes_from_tree():
	# Fill slot 0 first, then pick up into slot 1
	var item1: Area2D = _make_item(Vector2(30, 0))
	var item2: Area2D = _make_item(Vector2(40, 0))
	_simulate_item_enters_range(item1)
	_simulate_item_enters_range(item2)
	# item2 is in slot 1, active_slot is 0, so item2 should not be in tree
	assert_null(item2.get_parent())

func test_pick_up_sets_item_to_inventory_state():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	assert_eq(item.current_state, item.State.INVENTORY)

func test_pick_up_while_holding_stores_in_next_empty_slot():
	var item1: Area2D = _make_item(Vector2(30, 0))
	var item2: Area2D = _make_item(Vector2(40, 0))
	_simulate_item_enters_range(item1)
	# item1 is in slot 0 (active). Now pick up item2 — should go to slot 1.
	_simulate_item_enters_range(item2)
	assert_eq(player.inventory[0], item1)
	assert_eq(player.inventory[1], item2)
	# item1 should still be at HoldPosition (active slot unchanged)
	assert_eq(item1.get_parent(), player.get_node("HoldPosition"))

# --- Drop ---

func test_drop_clears_active_slot():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	player.drop_item()
	assert_null(player.inventory[0])

func test_drop_emits_inventory_changed():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	watch_signals(player)
	player.drop_item()
	assert_signal_emitted(player, "inventory_changed")

func test_drop_emits_item_dropped():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	watch_signals(player)
	player.drop_item()
	assert_signal_emitted(player, "item_dropped")

func test_drop_reparents_to_world():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	player.drop_item()
	assert_eq(item.get_parent(), player.get_parent())

func test_has_active_item_true_when_holding():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	assert_true(player.has_active_item())

func test_has_active_item_false_when_empty():
	assert_false(player.has_active_item())

# --- Use action ---

func test_use_item_calls_item_use_and_drops():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	player.use_item()
	assert_null(player.inventory[0])

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
	_simulate_item_enters_range(item1)
	_simulate_item_enters_range(item2)
	player.switch_to_slot(1)
	assert_eq(item2.get_parent(), player.get_node("HoldPosition"))

func test_switch_slot_removes_old_item_from_tree():
	var item1: Area2D = _make_item(Vector2(30, 0))
	var item2: Area2D = _make_item(Vector2(40, 0))
	_simulate_item_enters_range(item1)
	_simulate_item_enters_range(item2)
	player.switch_to_slot(1)
	assert_null(item1.get_parent())

func test_switch_slot_same_slot_does_nothing():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	player.switch_to_slot(0)
	assert_eq(item.get_parent(), player.get_node("HoldPosition"))

func test_switch_next_wraps_around():
	player.switch_to_slot(7)
	player.switch_next()
	assert_eq(player.active_slot, 0)

func test_switch_prev_wraps_around():
	player.switch_prev()
	assert_eq(player.active_slot, 7)

# --- Facing direction ---

func test_facing_direction_default_is_right():
	assert_eq(player.facing_direction, Vector2.RIGHT)

func test_snap_to_cardinal_right():
	assert_eq(player.snap_to_cardinal(Vector2(3.0, 1.0)), Vector2.RIGHT)

func test_snap_to_cardinal_left():
	assert_eq(player.snap_to_cardinal(Vector2(-3.0, 1.0)), Vector2.LEFT)

func test_snap_to_cardinal_up():
	assert_eq(player.snap_to_cardinal(Vector2(1.0, -3.0)), Vector2.UP)

func test_snap_to_cardinal_down():
	assert_eq(player.snap_to_cardinal(Vector2(1.0, 3.0)), Vector2.DOWN)

func test_snap_to_cardinal_diagonal_prefers_horizontal():
	# When abs(x) == abs(y), horizontal wins
	assert_eq(player.snap_to_cardinal(Vector2(1.0, 1.0)), Vector2.RIGHT)

func test_snap_to_cardinal_zero_returns_current_facing():
	player.facing_direction = Vector2.UP
	assert_eq(player.snap_to_cardinal(Vector2.ZERO), Vector2.UP)

# --- Directional drop ---

func test_get_drop_position_uses_facing_and_distance():
	player.global_position = Vector2(100, 100)
	player.facing_direction = Vector2.RIGHT
	player.drop_distance = 80.0
	assert_eq(player.get_drop_position(), Vector2(180, 100))

func test_get_drop_position_facing_left():
	player.global_position = Vector2(100, 100)
	player.facing_direction = Vector2.LEFT
	player.drop_distance = 80.0
	assert_eq(player.get_drop_position(), Vector2(20, 100))

func test_get_drop_position_facing_up():
	player.global_position = Vector2(100, 100)
	player.facing_direction = Vector2.UP
	player.drop_distance = 80.0
	assert_eq(player.get_drop_position(), Vector2(100, 20))

func test_drop_item_places_at_drop_position():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	player.global_position = Vector2(100, 100)
	player.facing_direction = Vector2.RIGHT
	player.drop_distance = 80.0
	player.drop_item()
	assert_eq(item.global_position, Vector2(180, 100))

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

func test_auto_pickup_ignores_turret_state_items():
	var item: Area2D = _make_item(Vector2(30, 0))
	item.drop()  # Set to TURRET state
	_simulate_item_enters_range(item)
	assert_false(player.inventory.has(item))

func test_drop_triggers_auto_pickup_of_nearby_items():
	# Fill all 8 slots
	var items: Array[Area2D] = []
	for i in range(8):
		var item: Area2D = _make_item(Vector2(30 + i * 10, 0))
		_simulate_item_enters_range(item)
		items.append(item)
	# Extra item enters range but can't be picked up (full)
	var extra: Area2D = _make_item(Vector2(200, 0))
	_simulate_item_enters_range(extra)
	assert_true(player._items_in_range.has(extra))
	# Drop active slot item — should auto-pickup extra
	player.drop_item()
	assert_eq(player.inventory[0], extra)
