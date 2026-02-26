# Character Facing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 4-cardinal-direction facing to the player that controls directional item dropping with a preview circle.

**Architecture:** All facing logic lives in `player.gd`. A static helper `snap_to_cardinal()` converts raw input to one of 4 cardinal directions. The drop preview is a `Node2D` child using `_draw()` for the circle. Zone validation for the drop target uses physics point queries.

**Tech Stack:** Godot 4, GDScript, GUT test framework

---

### Task 1: Add snap_to_cardinal helper and facing state to player

**Files:**
- Modify: `scenes/player/player.gd`
- Test: `core/tests/test_player.gd`

**Step 1: Write failing tests for snap_to_cardinal and facing state**

Add to `core/tests/test_player.gd`:

```gdscript
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
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `facing_direction` and `snap_to_cardinal` not defined

**Step 3: Implement facing state and snap_to_cardinal**

Add to `scenes/player/player.gd` after the `@export var camera_smoothing_speed` line:

```gdscript
@export var drop_distance: float = 80.0

var facing_direction: Vector2 = Vector2.RIGHT
```

Add this method to `player.gd`:

```gdscript
func snap_to_cardinal(raw: Vector2) -> Vector2:
	if raw.is_zero_approx():
		return facing_direction
	if absf(raw.x) >= absf(raw.y):
		return Vector2.RIGHT if raw.x >= 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if raw.y >= 0 else Vector2.UP
```

**Step 4: Run tests to verify they pass**

Run: `just test`
Expected: All new facing tests PASS

**Step 5: Commit**

```bash
git add scenes/player/player.gd core/tests/test_player.gd
git commit -m "feat(player): add snap_to_cardinal and facing_direction state (SCA-32)"
```

---

### Task 2: Add facing input (mouse + right joystick) to _physics_process

**Files:**
- Modify: `scenes/player/player.gd`
- Modify: `project.godot`

**Step 1: Add look input actions to project.godot**

Add these input actions to the `[input]` section of `project.godot` (before `[layer_names]`). These use right joystick axis events (device 0, axis 2 for horizontal, axis 3 for vertical):

```
look_left={
"deadzone": 0.2,
"events": [Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":2,"axis_value":-1.0,"script":null)
]
}
look_right={
"deadzone": 0.2,
"events": [Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":2,"axis_value":1.0,"script":null)
]
}
look_up={
"deadzone": 0.2,
"events": [Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":3,"axis_value":-1.0,"script":null)
]
}
look_down={
"deadzone": 0.2,
"events": [Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":3,"axis_value":1.0,"script":null)
]
}
```

**Step 2: Update _physics_process to update facing_direction**

In `scenes/player/player.gd`, update `_physics_process`:

```gdscript
func _physics_process(_delta):
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	# Update facing direction: joystick overrides mouse
	var look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.is_zero_approx():
		look = get_global_mouse_position() - global_position
	facing_direction = snap_to_cardinal(look)
```

**Step 3: Run validation**

Run: `just check`
Expected: Project validates successfully, all tests pass

**Step 4: Commit**

```bash
git add scenes/player/player.gd project.godot
git commit -m "feat(player): add facing input from mouse and right joystick (SCA-32)"
```

---

### Task 3: Modify drop_item to use facing direction

**Files:**
- Modify: `scenes/player/player.gd`
- Test: `core/tests/test_player.gd`

**Step 1: Write failing tests for directional dropping**

Add to `core/tests/test_player.gd`:

```gdscript
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
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `get_drop_position` not defined, drop position not offset

**Step 3: Add get_drop_position and update drop_item**

Add to `scenes/player/player.gd`:

```gdscript
func get_drop_position() -> Vector2:
	return global_position + facing_direction * drop_distance
```

Update `drop_item()` — change `var drop_pos: Vector2 = global_position` to use `get_drop_position()`:

```gdscript
func drop_item():
	var item: Area2D = inventory[active_slot]
	if item == null:
		return
	var drop_pos: Vector2 = get_drop_position()
	inventory[active_slot] = null
	item.drop()
	$HoldPosition.remove_child(item)
	get_parent().add_child(item)
	item.global_position = drop_pos
	inventory_changed.emit(active_slot, null)
	item_dropped.emit(item, drop_pos)
	_try_auto_pickup_from_range()
```

**Step 4: Run tests to verify they pass**

Run: `just test`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add scenes/player/player.gd core/tests/test_player.gd
git commit -m "feat(player): drop items at facing direction offset (SCA-32)"
```

---

### Task 4: Update can_drop to validate drop target position

**Files:**
- Modify: `scenes/player/player.gd`

**Step 1: Update can_drop to check drop position against tower zones**

Replace the current `can_drop()` method in `scenes/player/player.gd`:

```gdscript
func can_drop() -> bool:
	var drop_pos: Vector2 = get_drop_position()
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = drop_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results: Array[Dictionary] = space_state.intersect_point(query)
	for result in results:
		var collider = result["collider"]
		if "zone_type" in collider and collider.zone_type == ZoneScript.ZoneType.TOWER:
			return true
	return false
```

This replaces the old approach (checking player's PickupZone overlaps) with a point query at the target drop position.

**Step 2: Run validation**

Run: `just check`
Expected: Project validates, all tests pass. Note: `test_zone_dropping.gd` already acknowledges that physics overlaps aren't available in unit tests — the zone validation behavior is verified manually.

**Step 3: Commit**

```bash
git add scenes/player/player.gd
git commit -m "feat(player): validate drop position against tower zone (SCA-32)"
```

---

### Task 5: Add drop preview circle

**Files:**
- Create: `scenes/player/drop_preview.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scenes/player/player.gd`

**Step 1: Create the drop preview script**

Create `scenes/player/drop_preview.gd`:

```gdscript
extends Node2D

@export var radius: float = 12.0
@export var valid_color: Color = Color(0.2, 0.8, 0.2, 0.5)
@export var invalid_color: Color = Color(0.8, 0.2, 0.2, 0.5)

var is_valid: bool = true

func _draw() -> void:
	var color: Color = valid_color if is_valid else invalid_color
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color.lightened(0.3), 2.0)

func update_state(new_valid: bool) -> void:
	if is_valid != new_valid:
		is_valid = new_valid
		queue_redraw()
```

**Step 2: Add DropPreview node to the player scene**

Add to the end of `scenes/player/player.tscn`:

```
[ext_resource type="Script" path="res://scenes/player/drop_preview.gd" id="3"]

[node name="DropPreview" type="Node2D" parent="."]
script = ExtResource("3")
visible = false
```

Note: The `ext_resource` id and `load_steps` need to be updated. The current `load_steps=4`, so bump to `load_steps=5` and add the ext_resource with `id="3"`.

**Step 3: Update player.gd to manage the preview**

Add to `_physics_process` in `scenes/player/player.gd`, after the facing direction update:

```gdscript
	# Update drop preview
	var preview: Node2D = $DropPreview
	if has_active_item():
		preview.visible = true
		preview.global_position = get_drop_position()
		preview.update_state(can_drop())
	else:
		preview.visible = false
```

**Step 4: Run validation**

Run: `just check`
Expected: Project validates successfully, all tests pass

**Step 5: Commit**

```bash
git add scenes/player/drop_preview.gd scenes/player/player.tscn scenes/player/player.gd
git commit -m "feat(player): add drop preview circle showing target location (SCA-32)"
```

---

### Task 6: Final validation and cleanup

**Files:**
- No new files

**Step 1: Run full test suite**

Run: `just check`
Expected: All tests pass, project validates

**Step 2: Manual verification checklist**

Test in Godot editor:
- [ ] Moving mouse updates facing direction (snap to 4 cardinal directions)
- [ ] Preview circle appears when holding an item
- [ ] Preview circle is green inside tower zone, red outside
- [ ] Pressing Q drops item at preview position (not player position)
- [ ] Drop is rejected when preview is outside tower zone
- [ ] Right joystick overrides mouse for facing direction

**Step 3: Commit any fixes from manual testing**

If fixes are needed, commit them individually with descriptive messages.
