# Camera Lookahead Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a camera lookahead that smoothly shifts toward the player's facing direction, giving more visibility ahead.

**Architecture:** New script on the existing Camera2D child node. Uses Camera2D's built-in `offset` property, lerped each frame toward `facing_direction * lookahead_distance`. All parameters exposed as `@export` vars.

**Tech Stack:** Godot 4, GDScript, GUT test framework

---

### Task 1: Write camera lookahead script with test

**Files:**
- Create: `scenes/player/camera_lookahead.gd`
- Test: `core/tests/test_camera_lookahead.gd`

**Step 1: Write the failing test**

Create `core/tests/test_camera_lookahead.gd`:

```gdscript
extends GutTest

var player: CharacterBody2D

func before_each():
	GameManager.reset_inventory()
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	GameManager.register_player(player)

func _get_camera() -> Camera2D:
	return player.get_node("Camera2D")

# --- Offset responds to facing direction ---

func test_offset_moves_toward_facing_direction():
	player.facing_direction = Vector2.RIGHT
	var camera: Camera2D = _get_camera()
	# Simulate several frames
	for i in range(60):
		camera._process(0.016)
	# Offset should have moved toward the right
	assert_gt(camera.offset.x, 0.0, "Camera offset should shift right")

func test_offset_moves_toward_left_facing():
	player.facing_direction = Vector2.LEFT
	var camera: Camera2D = _get_camera()
	for i in range(60):
		camera._process(0.016)
	assert_lt(camera.offset.x, 0.0, "Camera offset should shift left")

func test_offset_returns_to_center_when_facing_unchanged():
	var camera: Camera2D = _get_camera()
	# Face right for a while
	player.facing_direction = Vector2.RIGHT
	for i in range(60):
		camera._process(0.016)
	var offset_after_right: float = camera.offset.x
	assert_gt(offset_after_right, 0.0)
	# Now face left — offset should decrease
	player.facing_direction = Vector2.LEFT
	for i in range(120):
		camera._process(0.016)
	assert_lt(camera.offset.x, offset_after_right, "Offset should move toward left")

func test_offset_respects_lookahead_distance():
	var camera: Camera2D = _get_camera()
	camera.lookahead_distance = 100.0
	player.facing_direction = Vector2.RIGHT
	# Run many frames to converge
	for i in range(300):
		camera._process(0.016)
	# Should converge close to 100 pixels
	assert_almost_eq(camera.offset.x, 100.0, 5.0, "Should converge near lookahead_distance")

func test_offset_starts_at_zero():
	var camera: Camera2D = _get_camera()
	assert_eq(camera.offset, Vector2.ZERO, "Offset should start at zero")
```

**Step 2: Run test to verify it fails**

Run: `just test core/tests/test_camera_lookahead.gd`
Expected: FAIL — Camera2D has no `_process` doing lookahead, no `lookahead_distance` property.

**Step 3: Write the camera lookahead script**

Create `scenes/player/camera_lookahead.gd`:

```gdscript
extends Camera2D

@export var lookahead_distance: float = 60.0
@export var lookahead_smoothing: float = 3.0

func _process(delta: float) -> void:
	var player: CharacterBody2D = get_parent() as CharacterBody2D
	if not player:
		return
	var target_offset: Vector2 = player.facing_direction * lookahead_distance
	offset = offset.lerp(target_offset, lookahead_smoothing * delta)
```

**Step 4: Run test to verify it passes**

Run: `just test core/tests/test_camera_lookahead.gd`
Expected: All 5 tests PASS.

**Step 5: Commit**

```bash
git add scenes/player/camera_lookahead.gd core/tests/test_camera_lookahead.gd
git commit -m "feat: add camera lookahead script with tests"
```

---

### Task 2: Wire up script in player scene and clean up

**Files:**
- Modify: `scenes/player/player.tscn:39-41` (Camera2D node)
- Modify: `scenes/player/player.gd:4,13` (remove camera_smoothing_speed)

**Step 1: Attach the script to Camera2D in player.tscn**

In `scenes/player/player.tscn`, add the script reference and update the Camera2D node.

Add to the `[ext_resource]` section:
```
[ext_resource type="Script" path="res://scenes/player/camera_lookahead.gd" id="4"]
```

Update the Camera2D node to:
```
[node name="Camera2D" type="Camera2D" parent="."]
script = ExtResource("4")
position_smoothing_enabled = true
position_smoothing_speed = 5.0
```

**Step 2: Remove camera_smoothing_speed from player.gd**

In `scenes/player/player.gd`:

- Delete line 4: `@export var camera_smoothing_speed: float = 5.0`
- Delete line 13: `$Camera2D.position_smoothing_speed = camera_smoothing_speed`

The `position_smoothing_speed` is already set to `5.0` directly on the Camera2D node in the `.tscn` file, so no functionality is lost.

**Step 3: Run all tests to verify nothing breaks**

Run: `just test`
Expected: All tests PASS, including existing `test_player.gd` tests.

**Step 4: Run project validation**

Run: `just check`
Expected: No errors.

**Step 5: Commit**

```bash
git add scenes/player/player.tscn scenes/player/player.gd
git commit -m "feat: wire camera lookahead into player scene, remove camera_smoothing_speed"
```

---

### Task 3: Delete old SCA-29 design doc

**Files:**
- Delete: `docs/plans/2026-02-25-framed-camera-design.md`

**Step 1: Delete the file**

```bash
rm docs/plans/2026-02-25-framed-camera-design.md
```

**Step 2: Commit**

```bash
git add docs/plans/2026-02-25-framed-camera-design.md
git commit -m "chore: remove obsolete SCA-29 framed camera design"
```

---

### Task 4: Manual verification

**No code changes.** Play the game and verify:

1. Camera smoothly shifts toward where you're aiming (mouse or joystick)
2. Moving the mouse/joystick around causes the camera to gently lead in that direction
3. The shift feels subtle (60px) and smooth, not jarring
4. Camera still follows the player position correctly (position smoothing unchanged)
5. Adjust `lookahead_distance` and `lookahead_smoothing` in Inspector if the feel needs tuning
