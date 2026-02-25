# Tidal Cycle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add animated tide that ebbs during day and rises during night, revealing/hiding items and gold based on tide position.

**Architecture:** The existing `Tide` ColorRect in `main.tscn` gets a new `tide.gd` script that owns ebb/rise tween animation and emits `tide_position_changed(left_edge_x)`. ItemSpawner and GoldSpawner connect to this signal to show/hide items reactively. GameManager is unchanged.

**Tech Stack:** GDScript, Godot 4 tweens, GUT testing framework

**Design doc:** `docs/plans/2026-02-26-tidal-cycle-design.md`

---

### Task 1: Create tide.gd script

**Files:**
- Create: `scenes/game/tide.gd`

**Step 1: Create the tide script**

```gdscript
extends ColorRect

signal tide_position_changed(left_edge_x: float)
signal tide_ebbed
signal tide_risen

@export var ebb_duration: float = 5.0
@export var rise_duration: float = 5.0
@export var ebb_ratio: float = 0.8

var _full_left: float
var _width: float
var _tween: Tween

func _ready() -> void:
	_full_left = offset_left
	_width = offset_right - offset_left
	GameManager.day_started.connect(_start_ebb)
	GameManager.night_started.connect(_start_rise)

func _start_ebb() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var target_left: float = _full_left + _width * ebb_ratio
	_tween = create_tween()
	_tween.tween_method(_update_tide_position, offset_left, target_left, ebb_duration)
	_tween.tween_callback(func(): tide_ebbed.emit())

func _start_rise() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_update_tide_position, offset_left, _full_left, rise_duration)
	_tween.tween_callback(func(): tide_risen.emit())

func _update_tide_position(left_x: float) -> void:
	offset_left = left_x
	tide_position_changed.emit(left_x)
```

**Key geometry note:** The tide covers `[offset_left, offset_right]`. During ebb, `offset_left` moves right, revealing items to its left. An item at position X is revealed (not under tide) when `X < left_edge_x`. During rise, `offset_left` moves left, covering items again.

**Step 2: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 3: Commit**

```bash
git add scenes/game/tide.gd
git commit -m "feat(tide): add tide script with ebb/rise tween animation (SCA-31)"
```

---

### Task 2: Write tide tests

**Files:**
- Create: `core/tests/test_tide.gd`

**Step 1: Write tests for tide logic**

```gdscript
extends GutTest

var _tide: ColorRect

func before_each() -> void:
	_tide = ColorRect.new()
	_tide.offset_left = 100.0
	_tide.offset_top = -400.0
	_tide.offset_right = 504.0
	_tide.offset_bottom = 393.0
	_tide.set_script(load("res://scenes/game/tide.gd"))
	add_child_autofree(_tide)

func test_ready_stores_initial_dimensions() -> void:
	assert_eq(_tide._full_left, 100.0)
	assert_eq(_tide._width, 404.0)

func test_update_tide_position_sets_offset_left() -> void:
	watch_signals(_tide)
	_tide._update_tide_position(250.0)
	assert_eq(_tide.offset_left, 250.0)

func test_update_tide_position_emits_signal() -> void:
	watch_signals(_tide)
	_tide._update_tide_position(250.0)
	assert_signal_emitted_with_parameters(_tide, "tide_position_changed", [250.0])

func test_ebb_target_calculation() -> void:
	# ebb_ratio=0.8, width=404, full_left=100
	# target = 100 + 404 * 0.8 = 423.2
	var expected_target: float = 100.0 + 404.0 * 0.8
	_tide._start_ebb()
	# Tween created, verify it exists
	assert_not_null(_tide._tween)
	assert_true(_tide._tween.is_valid())
```

**Step 2: Run tests**

Run: `just test`
Expected: All tests pass

**Step 3: Commit**

```bash
git add core/tests/test_tide.gd
git commit -m "test(tide): add unit tests for tide component (SCA-31)"
```

---

### Task 3: Modify item_spawner.gd for tide integration

**Files:**
- Modify: `scenes/game/item_spawner.gd`

**Step 1: Add tide_path export and signal connections**

Add at line 8 (after `sea_zone_path`):
```gdscript
@export var tide_path: NodePath
```

Add instance variable after `_sea_zone` (line 10):
```gdscript
var _tide: ColorRect
```

In `_ready()`, after the sea_zone setup (after line 29), add:
```gdscript
	if tide_path:
		_tide = get_node(tide_path) as ColorRect
		_tide.tide_position_changed.connect(_on_tide_position_changed)
		_tide.tide_risen.connect(_on_tide_risen)
```

**Step 2: Modify _on_day_started to spawn items hidden**

Replace `_on_day_started` (line 33-34):
```gdscript
func _on_day_started() -> void:
	_spawn_items()
	# Hide all newly spawned items — tide ebb will reveal them
	for item in _spawned_items:
		if is_instance_valid(item) and item.current_state == item.State.PICKUP:
			item.visible = false
```

**Step 3: Change _on_night_started to NOT cleanup immediately**

Replace `_on_night_started` (line 36-37). If tide is connected, defer cleanup to `tide_risen`. If no tide (backwards compat), cleanup immediately:
```gdscript
func _on_night_started() -> void:
	if _tide == null:
		_cleanup_uncollected_items()
```

**Step 4: Add tide signal handlers**

Add at end of file:
```gdscript
func _on_tide_position_changed(left_edge_x: float) -> void:
	for item in _spawned_items:
		if not is_instance_valid(item):
			continue
		if item.current_state != item.State.PICKUP:
			continue
		item.visible = item.global_position.x < left_edge_x

func _on_tide_risen() -> void:
	_cleanup_uncollected_items()
```

**Explanation:** `item.visible = item.global_position.x < left_edge_x` works for both ebb (left_edge moves right → more items revealed) and rise (left_edge moves left → items hidden). During ebb, items appear as tide passes them. During rise, items disappear as tide covers them. Turret-state items are skipped.

**Step 5: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 6: Commit**

```bash
git add scenes/game/item_spawner.gd
git commit -m "feat(item-spawner): integrate tide for item reveal/hide (SCA-31)"
```

---

### Task 4: Modify gold_spawner.gd for tide integration

**Files:**
- Modify: `scenes/game/gold_spawner.gd`

**Step 1: Add tide_path export, gold tracking, and signal connections**

Add at line 8 (after `gold_per_day`):
```gdscript
@export var tide_path: NodePath
```

Add instance variables after `_sea_zone` (line 12):
```gdscript
var _tide: ColorRect
var _spawned_gold: Array[Area2D] = []
```

In `_ready()`, after sea_zone setup (after line 18), add:
```gdscript
	if tide_path:
		_tide = get_node(tide_path) as ColorRect
		_tide.tide_position_changed.connect(_on_tide_position_changed)
		_tide.tide_risen.connect(_on_tide_risen)
```

**Step 2: Track spawned gold and hide at spawn**

Replace `_spawn_gold` (lines 28-35):
```gdscript
func _spawn_gold() -> void:
	if _spawn_area == null:
		push_error("GoldSpawner: spawn_area is not assigned.")
		return
	for _i in gold_per_day:
		var gold: Area2D = _gold_scene.instantiate()
		gold.global_position = _random_point_in_spawn_area()
		if _tide:
			gold.visible = false
		get_parent().add_child(gold)
		_spawned_gold.append(gold)
```

**Step 3: Change _on_night_started to defer cleanup**

Replace `_on_night_started` (lines 25-26):
```gdscript
func _on_night_started() -> void:
	if _tide == null:
		_cleanup_sea_gold()
```

**Step 4: Add tide signal handlers**

Add at end of file:
```gdscript
func _on_tide_position_changed(left_edge_x: float) -> void:
	for gold in _spawned_gold:
		if not is_instance_valid(gold):
			continue
		gold.visible = gold.global_position.x < left_edge_x

func _on_tide_risen() -> void:
	_cleanup_sea_gold()
	_spawned_gold.clear()
```

**Key detail:** Only gold tracked in `_spawned_gold` (spawned by GoldSpawner during day) is tide-managed. Gold dropped by killed monsters (spawned by MonsterSpawner) is NOT in this array and stays visible during night.

**Step 5: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 6: Commit**

```bash
git add scenes/game/gold_spawner.gd
git commit -m "feat(gold-spawner): integrate tide for gold reveal/hide (SCA-31)"
```

---

### Task 5: Update main.tscn to wire up tide script and node paths

**Files:**
- Modify: `scenes/game/main.tscn`

**Step 1: Add ext_resource for tide.gd**

Add after the last ext_resource line (after line 13, the toolbar resource):
```
[ext_resource type="Script" path="res://scenes/game/tide.gd" id="15"]
```

**Step 2: Add script and exports to Tide node**

Replace the Tide node block (lines 72-77) with:
```
[node name="Tide" type="ColorRect" parent="." unique_id=1481333432]
offset_left = 100.0
offset_top = -400.0
offset_right = 504.0
offset_bottom = 393.0
color = Color(0, 0.5921569, 0.7764706, 0.5803922)
script = ExtResource("15")
```

**Step 3: Add tide_path to ItemSpawner node**

Add `tide_path` to the ItemSpawner node (after line 42):
```
tide_path = NodePath("../Tide")
```

**Step 4: Add tide_path to GoldSpawner node**

Add `tide_path` to the GoldSpawner node (after line 47):
```
tide_path = NodePath("../Tide")
```

**Step 5: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 6: Run all tests**

Run: `just test`
Expected: All tests pass (including new tide tests)

**Step 7: Commit**

```bash
git add scenes/game/main.tscn
git commit -m "feat(scene): wire tide script and paths in main scene (SCA-31)"
```

---

### Task 6: Manual verification and final commit

**Step 1: Play-test in Godot editor**

Open Godot editor, run the game, and verify:
- [ ] Day starts: tide ebbs (shrinks from left), items appear one-by-one as tide passes them
- [ ] Gold also appears with tide ebb
- [ ] 20% of tide always remains (rightmost portion)
- [ ] Night starts: tide rises (expands from left), items/gold hide as tide covers them
- [ ] Items destroyed after tide fully rises
- [ ] Turret-placed items are NOT affected by tide
- [ ] Monster-dropped gold during night is NOT hidden by tide
- [ ] Ebb/rise duration feels right (adjust @export values if needed)
- [ ] Multiple day/night cycles work correctly

**Step 2: Create PR**

```bash
gh pr create --title "feat: tidal cycle for day/night transitions (SCA-31)" --body "Closes SCA-31"
```
