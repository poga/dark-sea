extends GutTest

const INVENTORY_SIZE: int = 8
var player: CharacterBody2D

func before_each() -> void:
	GameManager.gold = 0
	GameManager.reset_inventory()
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	GameManager.register_player(player)

func _make_item() -> Area2D:
	var item: Area2D = preload("res://scenes/item/turret_item.tscn").instantiate()
	add_child_autofree(item)
	return item

# --- Inventory state ---

func test_inventory_starts_empty():
	for i in range(INVENTORY_SIZE):
		assert_null(GameManager.inventory[i])

func test_active_slot_starts_at_zero():
	assert_eq(GameManager.active_slot, 0)

# --- Pickup ---

func test_try_pickup_stores_in_first_empty_slot():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	assert_eq(GameManager.inventory[0], item)

func test_try_pickup_emits_inventory_changed():
	watch_signals(GameManager)
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	assert_signal_emitted_with_parameters(GameManager, "inventory_changed", [0, item])

func test_try_pickup_sets_inventory_state():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	assert_eq(item.current_state, item.State.INVENTORY)

func test_try_pickup_returns_false_when_full():
	for i in range(INVENTORY_SIZE):
		GameManager.try_pickup(_make_item())
	var extra: Area2D = _make_item()
	assert_false(GameManager.try_pickup(extra))

func test_try_pickup_fills_next_empty_slot():
	GameManager.try_pickup(_make_item())
	var second: Area2D = _make_item()
	GameManager.try_pickup(second)
	assert_eq(GameManager.inventory[1], second)

# --- Slot switching ---

func test_switch_slot_changes_active():
	GameManager.switch_slot(3)
	assert_eq(GameManager.active_slot, 3)

func test_switch_slot_emits_active_slot_changed():
	watch_signals(GameManager)
	GameManager.switch_slot(2)
	assert_signal_emitted_with_parameters(GameManager, "active_slot_changed", [2])

func test_switch_slot_ignores_invalid():
	GameManager.switch_slot(-1)
	assert_eq(GameManager.active_slot, 0)
	GameManager.switch_slot(99)
	assert_eq(GameManager.active_slot, 0)

func test_switch_slot_ignores_same():
	watch_signals(GameManager)
	GameManager.switch_slot(0)
	assert_signal_not_emitted(GameManager, "active_slot_changed")

# --- Get active item ---

func test_get_active_item_returns_null_when_empty():
	assert_null(GameManager.get_active_item())

func test_get_active_item_returns_item_in_active_slot():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	assert_eq(GameManager.get_active_item(), item)

# --- Use item ---

func test_use_active_item_emits_attempted():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	watch_signals(GameManager)
	GameManager.use_active_item(Vector2(100, 0))
	assert_signal_emitted(GameManager, "item_use_attempted")

func test_use_active_item_on_empty_slot_does_nothing():
	watch_signals(GameManager)
	GameManager.use_active_item(Vector2(100, 0))
	assert_signal_not_emitted(GameManager, "item_use_attempted")

# --- Swap slots ---

func test_swap_slots_swaps_items():
	var item_a: Area2D = _make_item()
	var item_b: Area2D = _make_item()
	GameManager.try_pickup(item_a)
	GameManager.try_pickup(item_b)
	GameManager.swap_slots(0, 1)
	assert_eq(GameManager.inventory[0], item_b)
	assert_eq(GameManager.inventory[1], item_a)

func test_swap_slots_emits_inventory_changed_for_both():
	var item_a: Area2D = _make_item()
	var item_b: Area2D = _make_item()
	GameManager.try_pickup(item_a)
	GameManager.try_pickup(item_b)
	watch_signals(GameManager)
	GameManager.swap_slots(0, 1)
	assert_signal_emitted_with_parameters(GameManager, "inventory_changed", [0, item_b], 0)

func test_swap_slots_moves_to_empty():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	GameManager.swap_slots(0, 3)
	assert_null(GameManager.inventory[0])
	assert_eq(GameManager.inventory[3], item)

func test_swap_slots_with_active_slot_reparents():
	var item_a: Area2D = _make_item()
	var item_b: Area2D = _make_item()
	GameManager.try_pickup(item_a)
	GameManager.try_pickup(item_b)
	# active_slot is 0, swap 0 and 1
	GameManager.swap_slots(0, 1)
	# item_b should now be in HoldPosition (it moved to active slot 0)
	assert_eq(player.get_node("HoldPosition").get_child_count(), 1)
	assert_eq(player.get_node("HoldPosition").get_child(0), item_b)

func test_swap_same_slot_is_noop():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	watch_signals(GameManager)
	GameManager.swap_slots(0, 0)
	assert_signal_not_emitted(GameManager, "inventory_changed")
	assert_eq(GameManager.inventory[0], item)
