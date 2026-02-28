# Remove Target Vector Snapping — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace cardinal direction snapping with raw continuous vector input so items drop in any direction (360 degrees).

**Architecture:** Remove `snap_to_cardinal()` from `player.gd`, normalize the raw look vector directly, and update tests to match.

**Tech Stack:** GDScript, GUT testing framework

---

### Task 1: Update tests for continuous facing direction

**Files:**
- Modify: `core/tests/test_player.gd:19-37`

**Step 1: Replace snapping tests with continuous vector tests**

Remove the 5 `snap_to_cardinal` tests (lines 24-37) and the `test_default_facing_direction` test (line 21-22). Replace with:

```gdscript
# --- Facing direction ---

func test_default_facing_direction():
	assert_eq(player.facing_direction, Vector2.RIGHT)

func test_update_facing_normalizes_input():
	player.update_facing(Vector2(3, 4))
	assert_almost_eq(player.facing_direction, Vector2(0.6, 0.8), Vector2(0.001, 0.001))

func test_update_facing_preserves_direction_on_zero_input():
	player.update_facing(Vector2(1, 0))
	player.update_facing(Vector2.ZERO)
	assert_eq(player.facing_direction, Vector2.RIGHT)
```

**Step 2: Update drop position tests to use non-cardinal vectors**

Replace the two drop position tests (lines 41-49) with:

```gdscript
# --- Drop position ---

func test_get_drop_position_uses_facing_direction():
	player.facing_direction = Vector2.RIGHT
	var expected: Vector2 = player.global_position + Vector2.RIGHT * player.drop_distance
	assert_eq(player.get_drop_position(), expected)

func test_get_drop_position_diagonal():
	var dir: Vector2 = Vector2(1, 1).normalized()
	player.facing_direction = dir
	var expected: Vector2 = player.global_position + dir * player.drop_distance
	assert_almost_eq(player.get_drop_position(), expected, Vector2(0.001, 0.001))
```

**Step 3: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `update_facing` method does not exist yet.

**Step 4: Commit**

```
git add core/tests/test_player.gd
git commit -m "test: update facing direction tests for continuous vectors"
```

---

### Task 2: Replace snapping with normalization in player.gd

**Files:**
- Modify: `scenes/player/player.gd:25,38-44`

**Step 1: Add `update_facing()` method, remove `snap_to_cardinal()`**

Delete lines 38-44 (`snap_to_cardinal` function). Add this method in its place:

```gdscript
func update_facing(raw: Vector2) -> void:
	if not raw.is_zero_approx():
		facing_direction = raw.normalized()
```

**Step 2: Update `_physics_process` to call `update_facing`**

Change line 25 from:
```gdscript
	facing_direction = snap_to_cardinal(look)
```
to:
```gdscript
	update_facing(look)
```

**Step 3: Run tests to verify they pass**

Run: `just test`
Expected: All tests PASS.

**Step 4: Run project validation**

Run: `just check`
Expected: No parse errors.

**Step 5: Commit**

```
git add scenes/player/player.gd
git commit -m "feat: replace cardinal snapping with continuous facing direction"
```
