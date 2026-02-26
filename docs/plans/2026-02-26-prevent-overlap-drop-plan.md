# Prevent Overlap Drop Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent players from dropping items where their collision shape overlaps an existing turret.

**Architecture:** Modify `can_drop()` in `player.gd` to use a `CircleShape2D` shape query instead of a point query. The shape query detects both zone validity and turret overlap in a single pass. Drop preview automatically reflects this since it calls `can_drop()` every frame.

**Tech Stack:** GDScript, Godot 4 physics queries (`PhysicsShapeQueryParameters2D`, `CircleShape2D`)

---

### Task 1: Write failing test for turret overlap blocking drop

**Files:**
- Modify: `core/tests/test_player.gd`

**Step 1: Write the failing test**

Add these tests at the end of `test_player.gd` (before the helper section), after the auto-pickup tests:

```gdscript
# --- can_drop overlap ---

func test_can_drop_false_when_turret_overlaps_drop_position():
	# Place a turret at where the player would drop
	var turret: Area2D = _make_item(Vector2.ZERO)
	turret.drop()  # Set to TURRET state
	var drop_pos: Vector2 = player.get_drop_position()
	turret.global_position = drop_pos

	# Need physics to register the collision shapes
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_false(player.can_drop(), "should not drop on top of existing turret")

func test_can_drop_true_when_turret_far_from_drop_position():
	# Place a turret far away from drop position
	var turret: Area2D = _make_item(Vector2.ZERO)
	turret.drop()  # Set to TURRET state
	turret.global_position = Vector2(9999, 9999)

	# Add a tower zone at the drop position so zone check passes
	var zone: Area2D = _make_tower_zone(player.get_drop_position())

	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(player.can_drop(), "should allow drop when no turret overlaps")
```

Add the `_make_tower_zone` helper alongside the existing `_simulate_item_enters_range` helper:

```gdscript
func _make_tower_zone(pos: Vector2) -> Area2D:
	var zone := Area2D.new()
	zone.set_script(preload("res://scenes/zones/zone.gd"))
	zone.zone_type = zone.ZoneType.TOWER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 200.0
	shape.shape = circle
	zone.add_child(shape)
	add_child_autofree(zone)
	zone.global_position = pos
	return zone
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: `test_can_drop_false_when_turret_overlaps_drop_position` PASSES (point query doesn't find turrets, `can_drop()` returns false because no zone found — but turret is there). `test_can_drop_true_when_turret_far_from_drop_position` PASSES (zone present, no overlap check yet).

Actually — `test_can_drop_false_when_turret_overlaps_drop_position` will pass because `can_drop()` already returns false when no zone is at the drop position. The real test is `test_can_drop_true_when_turret_far_from_drop_position` — it should pass after implementation since zone is present and turret is far away. Both tests validate the new behavior but won't meaningfully fail before implementation.

The key behavioral change is: currently if a zone AND a turret are both at the drop position, `can_drop()` returns `true`. After the change it should return `false`. Add this test:

```gdscript
func test_can_drop_false_when_turret_overlaps_even_in_tower_zone():
	# Place a tower zone at the drop position
	var zone: Area2D = _make_tower_zone(player.get_drop_position())

	# Place a turret at the same drop position
	var turret: Area2D = _make_item(Vector2.ZERO)
	turret.drop()
	turret.global_position = player.get_drop_position()

	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_false(player.can_drop(), "should not drop on turret even inside tower zone")
```

This is the **key failing test**: with the current point query, it returns `true` (finds the tower zone). After implementation, it should return `false` (turret overlap blocks it).

**Step 3: Run test to verify the key test fails**

Run: `just test`
Expected: `test_can_drop_false_when_turret_overlaps_even_in_tower_zone` FAILS — currently returns `true` because zone is found and turret isn't checked.

**Step 4: Commit**

```bash
git add core/tests/test_player.gd
git commit -m "test: add failing tests for turret overlap blocking drop"
```

---

### Task 2: Implement shape query in can_drop()

**Files:**
- Modify: `scenes/player/player.gd:86-98` (the `can_drop()` method)

**Step 1: Replace can_drop() with shape query**

Replace the current `can_drop()` method in `player.gd` (lines 86-98) with:

```gdscript
func can_drop() -> bool:
	var drop_pos: Vector2 = get_drop_position()
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	query.shape = shape
	query.transform = Transform2D(0, drop_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results: Array[Dictionary] = space_state.intersect_shape(query)
	var in_tower_zone: bool = false
	for result in results:
		var collider = result["collider"]
		if "zone_type" in collider and collider.zone_type == ZoneScript.ZoneType.TOWER:
			in_tower_zone = true
		if collider is Area2D and collider.has_method("pick_up") and collider.current_state == collider.State.TURRET:
			return false
	return in_tower_zone
```

Logic:
- Creates a `CircleShape2D` with radius 20 (matching item collision) at the drop position
- Iterates all overlapping `Area2D` colliders
- If any is an item in TURRET state → immediately return `false`
- If a TOWER zone is found → mark as valid
- Return whether we're in a tower zone (same as before, but now turret overlap blocks)

**Step 2: Run tests to verify they pass**

Run: `just test`
Expected: All tests pass, including the new `test_can_drop_false_when_turret_overlaps_even_in_tower_zone`.

**Step 3: Run project validation**

Run: `just check`
Expected: No parse errors.

**Step 4: Commit**

```bash
git add scenes/player/player.gd
git commit -m "feat: block item drop when overlapping existing turret"
```

---

### Task 3: Manual verification

**Steps:**
1. Run the game
2. Drop a turret in a tower zone — should work (green preview)
3. Try to drop a second turret on top of the first — preview should turn red, drop should be blocked
4. Move slightly away so shapes don't overlap — preview should turn green, drop should work
5. Verify existing behavior: dropping outside tower zone still shows red and blocks
