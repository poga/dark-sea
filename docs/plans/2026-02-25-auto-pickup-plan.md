# Auto-Pickup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace manual Space-key pickup with automatic pickup when the player walks near items.

**Architecture:** Reuse the existing `PickupZone.area_entered` signal to trigger pickup immediately. Add a `_try_auto_pickup()` method that finds an empty slot and picks up the item. Remove the `interact` input action and related dead code.

**Tech Stack:** GDScript, Godot 4.6, GUT test framework

---

### Task 1: Add `_try_auto_pickup()` method and wire to area_entered signal

**Files:**
- Modify: `scenes/player/player.gd`
- Test: `core/tests/test_player.gd`

**Step 1: Write the failing test for auto-pickup on area_entered**

Add to `core/tests/test_player.gd`, replacing the `_pick_up_item` helper and relevant tests:

```gdscript
# Replace the old _pick_up_item helper with one that simulates area_entered
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
```

**Step 2: Run tests to verify they fail**

Run: `just check` (or Godot GUT runner)
Expected: FAIL — `test_auto_pickup_on_entering_range` fails because `_on_pickup_zone_area_entered` only appends to `_items_in_range` and doesn't pick up.

**Step 3: Implement `_try_auto_pickup()` in player.gd**

Add method and modify `_on_pickup_zone_area_entered`:

```gdscript
func _try_auto_pickup(item: Area2D) -> void:
	var slot: int = _find_empty_slot()
	if slot == -1:
		return
	_items_in_range.erase(item)
	item.get_parent().remove_child(item)
	item.store_in_inventory()
	inventory[slot] = item
	if slot == active_slot:
		$HoldPosition.add_child(item)
		item.position = Vector2.ZERO
	inventory_changed.emit(slot, item)
	item_picked_up.emit(item)

func _on_pickup_zone_area_entered(area: Area2D):
	if not inventory.has(area) and area.has_method("pick_up"):
		_items_in_range.append(area)
		_try_auto_pickup(area)
```

**Step 4: Run tests to verify they pass**

Run: `just check`
Expected: New auto-pickup tests PASS. Existing tests still pass.

**Step 5: Commit**

```bash
git add scenes/player/player.gd core/tests/test_player.gd
git commit -m "feat: add auto-pickup on entering PickupZone range"
```

---

### Task 2: Add auto-pickup on drop (edge case)

**Files:**
- Modify: `scenes/player/player.gd`
- Test: `core/tests/test_player.gd`

**Step 1: Write the failing test**

Add to `core/tests/test_player.gd`:

```gdscript
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
```

**Step 2: Run tests to verify it fails**

Run: `just check`
Expected: FAIL — `drop_item()` doesn't attempt auto-pickup after freeing a slot.

**Step 3: Implement auto-pickup after drop**

Modify `drop_item()` in `scenes/player/player.gd` — add a call to try picking up items in range at the end:

```gdscript
func drop_item():
	var item: Area2D = inventory[active_slot]
	if item == null:
		return
	var drop_pos: Vector2 = global_position
	inventory[active_slot] = null
	var zone = get_current_zone()
	if zone == ZoneScript.ZoneType.TOWER:
		item.drop()
	else:
		item.drop_as_pickup()
	$HoldPosition.remove_child(item)
	get_parent().add_child(item)
	item.global_position = drop_pos
	inventory_changed.emit(active_slot, null)
	item_dropped.emit(item, drop_pos)
	_try_auto_pickup_from_range()

func _try_auto_pickup_from_range() -> void:
	for item in _items_in_range.duplicate():
		if _find_empty_slot() == -1:
			break
		_try_auto_pickup(item)
```

**Step 4: Run tests to verify they pass**

Run: `just check`
Expected: PASS

**Step 5: Commit**

```bash
git add scenes/player/player.gd core/tests/test_player.gd
git commit -m "feat: auto-pickup nearby items after dropping"
```

---

### Task 3: Remove interact input and dead code

**Files:**
- Modify: `scenes/player/player.gd`
- Modify: `project.godot`
- Modify: `core/tests/test_player.gd`

**Step 1: Remove `interact` handling from `_unhandled_input()`**

In `scenes/player/player.gd`, remove these lines from `_unhandled_input`:

```gdscript
	if event.is_action_pressed("interact"):
		pick_up_nearest_item()
		return
```

**Step 2: Remove `pick_up_nearest_item()` and `get_nearest_item()` methods**

Delete these two functions entirely from `scenes/player/player.gd`:

- `get_nearest_item()` (lines 52-62)
- `pick_up_nearest_item()` (lines 70-85)

**Step 3: Remove `interact` input action from `project.godot`**

Remove lines 51-55 from `project.godot`:

```
interact={
"deadzone": 0.2,
"events": [Object(InputEventKey,...,"physical_keycode":32,...)]
}
```

**Step 4: Update tests — remove tests for deleted methods, update `_pick_up_item` helper**

In `core/tests/test_player.gd`:

- Remove `_pick_up_item` helper (replaced by `_simulate_item_enters_range` in Task 1)
- Remove `test_get_nearest_item_returns_null_when_empty`
- Remove `test_get_nearest_item_returns_closest`
- Remove `test_pick_up_does_nothing_when_no_items`
- Remove `test_pick_up_removes_from_items_in_range`
- Update remaining tests that used `_pick_up_item` to use `_simulate_item_enters_range` instead:
  - `test_pick_up_stores_in_first_empty_slot`
  - `test_pick_up_second_item_uses_slot_1`
  - `test_pick_up_emits_inventory_changed`
  - `test_pick_up_emits_item_picked_up`
  - `test_pick_up_active_slot_reparents_to_hold_position`
  - `test_pick_up_non_active_slot_removes_from_tree`
  - `test_pick_up_sets_item_to_inventory_state`
  - `test_pick_up_blocked_when_inventory_full`
  - `test_pick_up_while_holding_stores_in_next_empty_slot`
  - All drop tests that call `_pick_up_item`
  - All slot switching tests that call `_pick_up_item`

Each `_pick_up_item(item)` call becomes `_simulate_item_enters_range(item)`.

**Step 5: Run all tests**

Run: `just check`
Expected: All tests PASS. No references to `interact`, `pick_up_nearest_item`, or `get_nearest_item` remain.

**Step 6: Commit**

```bash
git add scenes/player/player.gd project.godot core/tests/test_player.gd
git commit -m "refactor: remove interact input and manual pickup dead code"
```
