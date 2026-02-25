# Inventory & Pickup Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove Beach zone, simplify dropping to tower-only turret placement, add long-press turret reclaim.

**Architecture:** Two zones (Tower, Sea). Drop always places turret. Auto-pickup only for PICKUP-state items. Turrets reclaimed via hold interact key near placed turret. `drop_as_pickup()` kept on item for future use.

**Tech Stack:** GDScript, Godot 4.6, GUT test framework

---

### Task 1: Remove Beach Zone

**Files:**
- Modify: `scenes/zones/zone.gd:3` (remove BEACH from enum)
- Modify: `scenes/game/main.tscn:4,27-28` (remove beach_zone ext_resource and node)
- Delete: `scenes/zones/beach_zone.tscn`

**Step 1: Remove BEACH from ZoneType enum**

In `scenes/zones/zone.gd`, change line 3:
```gdscript
# Before:
enum ZoneType { TOWER, BEACH, SEA }

# After:
enum ZoneType { TOWER, SEA }
```

Also change the default export on line 5:
```gdscript
# Before:
@export var zone_type: ZoneType = ZoneType.BEACH

# After:
@export var zone_type: ZoneType = ZoneType.TOWER
```

**Step 2: Remove BeachZone from main.tscn**

In `scenes/game/main.tscn`:
- Remove the ext_resource line: `[ext_resource type="PackedScene" path="res://scenes/zones/beach_zone.tscn" id="4"]`
- Remove the node lines:
```
[node name="BeachZone" parent="Zones" instance=ExtResource("4")]
position = Vector2(-100, 0)
```

**Step 3: Delete beach_zone.tscn**

```bash
rm scenes/zones/beach_zone.tscn
```

**Step 4: Run `just check` to validate**

Run: `just check`
Expected: Project validates successfully

**Step 5: Commit**

```bash
git add -A && git commit -m "refactor: remove Beach zone"
```

---

### Task 2: Simplify drop_item() to tower-only

**Files:**
- Modify: `scenes/player/player.gd:62-85`
- Modify: `core/tests/test_zone_dropping.gd`
- Modify: `core/tests/test_player.gd`

**Step 1: Update can_drop() to require Tower zone**

In `scenes/player/player.gd`, change `can_drop()`:
```gdscript
# Before:
func can_drop() -> bool:
	var zone = get_current_zone()
	if zone == null:
		return false
	return zone != ZoneScript.ZoneType.SEA

# After:
func can_drop() -> bool:
	return get_current_zone() == ZoneScript.ZoneType.TOWER
```

**Step 2: Simplify drop_item() — always drop as turret**

In `scenes/player/player.gd`, change `drop_item()`:
```gdscript
# Before:
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
	_recently_dropped.append(item)
	_try_auto_pickup_from_range()

# After:
func drop_item():
	var item: Area2D = inventory[active_slot]
	if item == null:
		return
	var drop_pos: Vector2 = global_position
	inventory[active_slot] = null
	item.drop()
	$HoldPosition.remove_child(item)
	get_parent().add_child(item)
	item.global_position = drop_pos
	inventory_changed.emit(active_slot, null)
	item_dropped.emit(item, drop_pos)
	_try_auto_pickup_from_range()
```

**Step 3: Remove `_recently_dropped` tracking**

In `scenes/player/player.gd`:
- Remove line `var _recently_dropped: Array[Area2D] = []`
- In `_on_pickup_zone_area_entered`, remove `and not _recently_dropped.has(area)` condition
- In `_on_pickup_zone_area_exited`, remove `_recently_dropped.erase(area)` line

**Step 4: Update test_zone_dropping.gd**

Replace `test_drop_in_beach_zone_keeps_pickup_state` with a test that verifies can_drop() returns false outside tower:

```gdscript
# Remove:
func test_drop_in_beach_zone_keeps_pickup_state():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	item.drop_as_pickup()
	assert_eq(item.current_state, item.State.PICKUP)

# Keep existing tests, they still apply:
# test_can_drop_returns_false_when_no_zone - still valid
# test_drop_in_tower_zone_sets_turret_state - still valid
```

**Step 5: Run `just check` and tests**

Run: `just check`
Expected: Project validates successfully

Run: `cd /Users/poga/projects/dark-sea && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gexit 2>&1 | tail -20`
Expected: All tests pass

**Step 6: Commit**

```bash
git add scenes/player/player.gd core/tests/test_zone_dropping.gd && git commit -m "refactor: simplify dropping to tower-only turret placement"
```

---

### Task 3: Auto-pickup only PICKUP-state items

**Files:**
- Modify: `scenes/player/player.gd:128-131`
- Modify: `core/tests/test_player.gd`

**Step 1: Write failing test — turrets not auto-picked up**

In `core/tests/test_player.gd`, add:
```gdscript
func test_auto_pickup_ignores_turret_state_items():
	var item: Area2D = _make_item(Vector2(30, 0))
	item.drop()  # Set to TURRET state
	_simulate_item_enters_range(item)
	assert_false(player.inventory.has(item))
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/poga/projects/dark-sea && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gtest=test_player.gd -gexit 2>&1 | tail -20`
Expected: FAIL — turret-state item gets auto-picked up

**Step 3: Add state check to _on_pickup_zone_area_entered**

In `scenes/player/player.gd`, update `_on_pickup_zone_area_entered`:
```gdscript
# Before:
func _on_pickup_zone_area_entered(area: Area2D):
	if not inventory.has(area) and area.has_method("pick_up"):
		_items_in_range.append(area)
		_try_auto_pickup.call_deferred(area)

# After:
func _on_pickup_zone_area_entered(area: Area2D):
	if not inventory.has(area) and area.has_method("pick_up") and area.current_state == area.State.PICKUP:
		_items_in_range.append(area)
		_try_auto_pickup.call_deferred(area)
```

**Step 4: Run tests to verify all pass**

Run: `cd /Users/poga/projects/dark-sea && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gexit 2>&1 | tail -20`
Expected: All tests pass

**Step 5: Commit**

```bash
git add scenes/player/player.gd core/tests/test_player.gd && git commit -m "feat: auto-pickup only items in PICKUP state, ignore turrets"
```

---

### Task 4: Add "interact" input action

**Files:**
- Modify: `project.godot` (add interact input action, key E)

**Step 1: Add interact action to project.godot**

Add after the `slot_next` block in the `[input]` section:
```
interact={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"location":0,"echo":false,"script":null)
]
}
```

(physical_keycode 69 = E key)

**Step 2: Run `just check`**

Run: `just check`
Expected: Project validates successfully

**Step 3: Commit**

```bash
git add project.godot && git commit -m "feat: add interact input action (E key)"
```

---

### Task 5: Implement long-press turret reclaim

**Files:**
- Modify: `scenes/player/player.gd`
- Modify: `core/tests/test_player.gd`

**Step 1: Write failing test — reclaim_turret stores in inventory**

In `core/tests/test_player.gd`, add:
```gdscript
# --- Turret reclaim ---

func test_reclaim_turret_stores_in_inventory():
	var item: Area2D = _make_item(Vector2(30, 0))
	item.drop()  # TURRET state
	player.reclaim_turret(item)
	assert_true(player.inventory.has(item))
	assert_eq(item.current_state, item.State.INVENTORY)

func test_reclaim_turret_emits_signals():
	var item: Area2D = _make_item(Vector2(30, 0))
	item.drop()
	watch_signals(player)
	player.reclaim_turret(item)
	assert_signal_emitted(player, "inventory_changed")
	assert_signal_emitted(player, "item_picked_up")

func test_reclaim_turret_fails_when_inventory_full():
	for i in range(8):
		var filler: Area2D = _make_item(Vector2(30 + i * 10, 0))
		_simulate_item_enters_range(filler)
	var turret: Area2D = _make_item(Vector2(200, 0))
	turret.drop()
	player.reclaim_turret(turret)
	assert_false(player.inventory.has(turret))
	assert_eq(turret.current_state, turret.State.TURRET)
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/poga/projects/dark-sea && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gtest=test_player.gd -gexit 2>&1 | tail -20`
Expected: FAIL — `reclaim_turret` not defined

**Step 3: Implement reclaim_turret and hold-to-reclaim logic**

In `scenes/player/player.gd`, add exports and state variables:
```gdscript
@export var reclaim_hold_time: float = 1.0

var _turrets_in_range: Array[Area2D] = []
var _reclaim_timer: float = 0.0
var _is_reclaiming: bool = false
```

Add turret range tracking to `_on_pickup_zone_area_entered` and `_on_pickup_zone_area_exited`:
```gdscript
func _on_pickup_zone_area_entered(area: Area2D):
	if inventory.has(area):
		return
	if area.has_method("pick_up") and area.current_state == area.State.PICKUP:
		_items_in_range.append(area)
		_try_auto_pickup.call_deferred(area)
	elif area.has_method("pick_up") and area.current_state == area.State.TURRET:
		_turrets_in_range.append(area)

func _on_pickup_zone_area_exited(area: Area2D):
	if not "zone_type" in area:
		_items_in_range.erase(area)
		_turrets_in_range.erase(area)
		if _turrets_in_range.is_empty():
			_reclaim_timer = 0.0
			_is_reclaiming = false
```

Add reclaim processing to `_physics_process`:
```gdscript
func _physics_process(delta):
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	if _is_reclaiming:
		_reclaim_timer += delta
		if _reclaim_timer >= reclaim_hold_time:
			_is_reclaiming = false
			_reclaim_timer = 0.0
			var target: Area2D = _get_nearest_turret()
			if target:
				reclaim_turret(target)
```

Add to `_unhandled_input`:
```gdscript
	if event.is_action_pressed("interact"):
		if not _turrets_in_range.is_empty():
			_is_reclaiming = true
			_reclaim_timer = 0.0
		return
	if event.is_action_released("interact"):
		_is_reclaiming = false
		_reclaim_timer = 0.0
		return
```

Add helper and reclaim method:
```gdscript
func _get_nearest_turret() -> Area2D:
	var nearest: Area2D = null
	var nearest_dist: float = INF
	for turret in _turrets_in_range:
		if not is_instance_valid(turret):
			continue
		var dist: float = global_position.distance_to(turret.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = turret
	return nearest

func reclaim_turret(turret: Area2D) -> void:
	var slot: int = _find_empty_slot()
	if slot == -1:
		return
	_turrets_in_range.erase(turret)
	turret.get_parent().remove_child(turret)
	turret.store_in_inventory()
	inventory[slot] = turret
	if slot == active_slot:
		$HoldPosition.add_child(turret)
		turret.position = Vector2.ZERO
	inventory_changed.emit(slot, turret)
	item_picked_up.emit(turret)
```

**Step 4: Run tests to verify all pass**

Run: `cd /Users/poga/projects/dark-sea && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gexit 2>&1 | tail -20`
Expected: All tests pass

**Step 5: Run `just check`**

Run: `just check`
Expected: Project validates successfully

**Step 6: Commit**

```bash
git add scenes/player/player.gd core/tests/test_player.gd && git commit -m "feat: add long-press turret reclaim with interact key"
```

---

### Task 6: Final validation

**Step 1: Run full test suite**

Run: `cd /Users/poga/projects/dark-sea && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gexit 2>&1 | tail -30`
Expected: All tests pass, no failures

**Step 2: Run `just check`**

Run: `just check`
Expected: Project validates successfully

**Step 3: Verify no stale references to Beach**

Search for any remaining Beach references:
```bash
grep -r "BEACH\|beach\|BeachZone" --include="*.gd" --include="*.tscn" --include="*.tres" .
```
Expected: No matches (or only the design doc)
