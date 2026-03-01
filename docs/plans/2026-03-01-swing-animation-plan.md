# Swing Down Animation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a tween-based "swing down" animation to held items that plays when the player uses an item, with effect firing at the impact point.

**Architecture:** Tween-based animation in `base_item.gd` with `@export` vars for per-item tuning. `GameManager.use_active_item()` starts the swing and defers the actual `use()` call to the impact callback. `is_swinging` flag blocks re-use during animation.

**Tech Stack:** GDScript, Godot Tween API, GUT test framework

---

### Task 1: Add swing exports and is_swinging to base_item

**Files:**
- Test: `core/tests/test_swing.gd` (create)
- Modify: `scenes/item/base_item.gd`

**Step 1: Write the failing tests**

Create `core/tests/test_swing.gd`:

```gdscript
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
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `is_swinging`, `swing_duration`, `swing_angle` not defined on base_item

**Step 3: Add swing properties to base_item.gd**

In `scenes/item/base_item.gd`, add after the existing `@export` vars:

```gdscript
@export var swing_duration: float = 0.3
@export var swing_angle: float = 45.0

var is_swinging: bool = false
var _swing_tween: Tween
```

**Step 4: Run tests to verify they pass**

Run: `just test`
Expected: PASS — all 3 new tests pass, all existing tests still pass

**Step 5: Commit**

```bash
git add core/tests/test_swing.gd scenes/item/base_item.gd
git commit -m "feat: add swing animation properties to base_item"
```

---

### Task 2: Implement play_swing method

**Files:**
- Test: `core/tests/test_swing.gd` (modify)
- Modify: `scenes/item/base_item.gd`

**Step 1: Write the failing tests**

Add to `core/tests/test_swing.gd`:

```gdscript
func test_play_swing_sets_is_swinging():
	var called := false
	item.play_swing(Vector2.RIGHT, func(): called = true)
	assert_true(item.is_swinging)

func test_play_swing_creates_valid_tween():
	item.play_swing(Vector2.RIGHT, func(): pass)
	assert_not_null(item._swing_tween)
	assert_true(item._swing_tween.is_valid())
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `play_swing` method not defined

**Step 3: Implement play_swing in base_item.gd**

Add to `scenes/item/base_item.gd` after the virtual methods section:

```gdscript
# --- Swing animation ---

func play_swing(facing: Vector2, on_impact: Callable) -> void:
	is_swinging = true
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	var direction: float = 1.0 if facing.x >= 0 else -1.0
	var target_angle: float = deg_to_rad(swing_angle) * direction
	_swing_tween.tween_property(self, "rotation", target_angle, swing_duration).set_ease(Tween.EASE_IN)
	_swing_tween.tween_interval(0.05)
	_swing_tween.tween_callback(on_impact)
	_swing_tween.tween_callback(func():
		rotation = 0.0
		is_swinging = false
	)
```

**Step 4: Run tests to verify they pass**

Run: `just test`
Expected: PASS — all swing tests pass, all existing tests still pass

**Step 5: Commit**

```bash
git add core/tests/test_swing.gd scenes/item/base_item.gd
git commit -m "feat: implement play_swing tween method on base_item"
```

---

### Task 3: Wire swing into GameManager.use_active_item

**Files:**
- Test: `core/tests/test_swing.gd` (modify)
- Modify: `core/game_manager.gd`

**Step 1: Write the failing tests**

Add to `core/tests/test_swing.gd`. These tests need the full player + inventory setup:

```gdscript
var player: CharacterBody2D

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
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `is_swinging` not checked in GameManager, swing not started

**Step 3: Refactor GameManager.use_active_item**

Replace `use_active_item` in `core/game_manager.gd` and extract `_apply_item_use`:

```gdscript
func use_active_item(target_position: Vector2) -> void:
	var item: Area2D = get_active_item()
	if item == null:
		return
	if item.is_swinging:
		return
	item_use_attempted.emit(item)
	var context: Dictionary = {
		"target_position": target_position,
		"player": _player,
	}
	if not item.can_use(context):
		item_use_failed.emit(item)
		return
	var facing: Vector2 = _player.facing_direction if _player else Vector2.RIGHT
	item.play_swing(facing, func(): _apply_item_use(item, context))

func _apply_item_use(item: Area2D, context: Dictionary) -> void:
	var result: int = item.use(context)
	if result == item.UseResult.NOTHING:
		item_use_failed.emit(item)
		return
	match result:
		item.UseResult.KEEP:
			pass  # item stays in inventory
		item.UseResult.CONSUME:
			inventory[active_slot] = null
			if _player:
				_player.get_node("HoldPosition").remove_child(item)
			item.queue_free()
			inventory_changed.emit(active_slot, null)
		item.UseResult.PLACE:
			inventory[active_slot] = null
			if _player:
				_player.get_node("HoldPosition").remove_child(item)
				_player.get_parent().add_child(item)
			item.global_position = context.target_position
			item.activate()
			inventory_changed.emit(active_slot, null)
	item_used.emit(item, result)
```

**Step 4: Run tests to verify they pass**

Run: `just test`
Expected: PASS — all tests pass including existing `test_use_active_item_emits_attempted` in test_inventory.gd

**Step 5: Commit**

```bash
git add core/tests/test_swing.gd core/game_manager.gd
git commit -m "feat: wire swing animation into GameManager.use_active_item"
```

---

### Task 4: Run full test suite and verify

**Files:** None (verification only)

**Step 1: Run all tests**

Run: `just test`
Expected: ALL tests pass. Pay attention to:
- `test_inventory.gd` — existing use_active_item tests still work
- `test_item.gd` — existing item tests unaffected
- `test_swing.gd` — all new swing tests pass

**Step 2: Run project validation**

Run: `just check`
Expected: No parse errors

**Step 3: Manual verification**

Launch the game and test:
- Hold an item and click to use — should see the downward swing
- Spam-click — should be blocked during swing
- Try with hammer (KEEP result) and default item (CONSUME result)
- Verify the swing direction flips based on mouse position relative to player

**Step 4: Commit any fixes if needed**
