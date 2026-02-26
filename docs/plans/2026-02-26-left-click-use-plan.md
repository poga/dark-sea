# Left-Click Use Action Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Q-key drop with left-click "use" action. Items define their own `use()` behavior; default = drop as turret.

**Architecture:** Add `use()` virtual method to `base_item.gd`. Player listens for `use` input action (left-click) and delegates to the active item's `use()`. Rename `drop` input to `use` in project.godot.

**Tech Stack:** Godot 4.6, GDScript, GUT test framework

---

### Task 1: Add `use()` method to base_item.gd

**Files:**
- Modify: `scenes/item/base_item.gd:59` (virtual methods section)
- Test: `core/tests/test_item.gd`

**Step 1: Write the failing test**

Add to `core/tests/test_item.gd`:

```gdscript
func test_use_returns_true_by_default():
	assert_true(item.use(null))
```

**Step 2: Run test to verify it fails**

Run: `just check && godot --headless -s addons/gut/gut_cmdln.gd -gtest=core/tests/test_item.gd -gunit_test_name=test_use_returns_true_by_default`
Expected: FAIL — `use` method does not exist

**Step 3: Write minimal implementation**

Add to `scenes/item/base_item.gd` after line 58 (in the virtual methods section), before `# --- Internal methods ---`:

```gdscript
func use(_player: CharacterBody2D) -> bool:
	return true
```

This is intentionally minimal — it just returns true. The player will handle the drop logic when `use()` returns true. Items that want custom behavior override this and return false to skip the default drop.

**Step 4: Run test to verify it passes**

Run: `just check && godot --headless -s addons/gut/gut_cmdln.gd -gtest=core/tests/test_item.gd -gunit_test_name=test_use_returns_true_by_default`
Expected: PASS

**Step 5: Commit**

```bash
git add scenes/item/base_item.gd core/tests/test_item.gd
git commit -m "feat(item): add use() virtual method to base_item"
```

---

### Task 2: Replace `drop` input with `use` (left-click) in project.godot

**Files:**
- Modify: `project.godot:51-55`

**Step 1: Replace the drop input action**

In `project.godot`, replace the `drop` action (lines 51-55) with a `use` action mapped to left mouse button:

```ini
use={
"deadzone": 0.2,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"double_click":false,"script":null)
]
}
```

**Step 2: Verify project loads**

Run: `just check`
Expected: No errors

**Step 3: Commit**

```bash
git add project.godot
git commit -m "feat(input): replace drop (Q) with use (left-click) action"
```

---

### Task 3: Wire player to use the `use` action and item's `use()` method

**Files:**
- Modify: `scenes/player/player.gd:55-59`
- Test: `core/tests/test_player.gd`

**Step 1: Write the failing test**

Add to `core/tests/test_player.gd`, after the existing drop tests section (~line 115):

```gdscript
# --- Use action ---

func test_use_item_calls_item_use_and_drops():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	player.use_item()
	assert_null(player.inventory[0])
```

**Step 2: Run test to verify it fails**

Run: `just check && godot --headless -s addons/gut/gut_cmdln.gd -gtest=core/tests/test_player.gd -gunit_test_name=test_use_item_calls_item_use_and_drops`
Expected: FAIL — `use_item` method does not exist

**Step 3: Write the implementation**

In `scenes/player/player.gd`:

1. Change `_unhandled_input` (line 55-59) to listen for `use` instead of `drop`:

```gdscript
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("use"):
		if has_active_item() and can_drop():
			use_item()
		return
```

2. Add a new `use_item()` method after `drop_item()` (after line 115):

```gdscript
func use_item():
	var item: Area2D = inventory[active_slot]
	if item == null:
		return
	if item.use(self):
		drop_item()
```

**Step 4: Run test to verify it passes**

Run: `just check && godot --headless -s addons/gut/gut_cmdln.gd -gtest=core/tests/test_player.gd -gunit_test_name=test_use_item_calls_item_use_and_drops`
Expected: PASS

**Step 5: Run all player tests to check nothing broke**

Run: `just check && godot --headless -s addons/gut/gut_cmdln.gd -gtest=core/tests/test_player.gd`
Expected: All tests PASS (existing drop tests still call `drop_item()` directly, so they remain valid)

**Step 6: Commit**

```bash
git add scenes/player/player.gd core/tests/test_player.gd
git commit -m "feat(player): wire use action to item use() with drop fallback"
```

---

### Task 4: Test that custom use() override skips drop

**Files:**
- Test: `core/tests/test_player.gd`

**Step 1: Write the test**

Add to `core/tests/test_player.gd`:

```gdscript
func test_use_item_skips_drop_when_use_returns_false():
	var item: Area2D = _make_item(Vector2(30, 0))
	# Override use() to return false (simulating custom item behavior)
	var script: GDScript = GDScript.new()
	script.source_code = """extends "res://scenes/item/base_item.gd"
func use(_player: CharacterBody2D) -> bool:
	return false
"""
	script.reload()
	item.set_script(script)
	_simulate_item_enters_range(item)
	player.use_item()
	# Item should still be in inventory because use() returned false
	assert_eq(player.inventory[0], item)
```

**Step 2: Run the test**

Run: `just check && godot --headless -s addons/gut/gut_cmdln.gd -gtest=core/tests/test_player.gd -gunit_test_name=test_use_item_skips_drop_when_use_returns_false`
Expected: PASS (use_item already checks the return value)

**Step 3: Commit**

```bash
git add core/tests/test_player.gd
git commit -m "test(player): verify custom use() override prevents drop"
```

---

### Task 5: Run full test suite and verify

**Step 1: Run all tests**

Run: `just check && godot --headless -s addons/gut/gut_cmdln.gd -gdir=core/tests/`
Expected: All tests PASS

**Step 2: Commit (if any fixes needed)**

Only if fixes were required. Otherwise, done.
