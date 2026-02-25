# Framed Camera Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the direct-follow camera with a dead-zone "framed" camera that only moves when the player exits a safe zone in the center of the screen.

**Architecture:** Use Godot Camera2D's built-in drag margin system. Enable drag on both axes with 0.3 margins, keep position smoothing for smooth catch-up. Remove the now-unnecessary `camera_smoothing_speed` export from the player script.

**Tech Stack:** Godot 4 Camera2D built-in properties, `.tscn` scene file editing.

---

### Task 1: Enable drag margins on Camera2D in player scene

**Files:**
- Modify: `scenes/player/player.tscn:38-40` (Camera2D node)

**Step 1: Edit the Camera2D node properties in the scene file**

In `scenes/player/player.tscn`, replace the Camera2D node block:

```
[node name="Camera2D" type="Camera2D" parent="."]
position_smoothing_enabled = true
position_smoothing_speed = 5.0
```

With:

```
[node name="Camera2D" type="Camera2D" parent="."]
drag_horizontal_enabled = true
drag_vertical_enabled = true
drag_left_margin = 0.3
drag_right_margin = 0.3
drag_top_margin = 0.3
drag_bottom_margin = 0.3
position_smoothing_enabled = true
position_smoothing_speed = 5.0
```

**Step 2: Validate the scene parses correctly**

Run: `just check`
Expected: No errors related to player.tscn

---

### Task 2: Remove camera_smoothing_speed export from player script

**Files:**
- Modify: `scenes/player/player.gd:12` (remove export)
- Modify: `scenes/player/player.gd:21` (remove _ready line)

**Step 1: Remove the `camera_smoothing_speed` export variable**

In `scenes/player/player.gd`, remove this line (line 12):

```gdscript
@export var camera_smoothing_speed: float = 5.0
```

**Step 2: Remove the Camera2D smoothing speed assignment in `_ready()`**

In `scenes/player/player.gd`, remove this line from `_ready()` (line 21):

```gdscript
	$Camera2D.position_smoothing_speed = camera_smoothing_speed
```

The `_ready()` function should now look like:

```gdscript
func _ready():
	inventory.resize(INVENTORY_SIZE)
	inventory.fill(null)
	$PickupZone.area_entered.connect(_on_pickup_zone_area_entered)
	$PickupZone.area_exited.connect(_on_pickup_zone_area_exited)
```

**Step 3: Validate scripts parse correctly**

Run: `just check`
Expected: No errors

---

### Task 3: Commit and verify

**Step 1: Run full validation**

Run: `just check`
Expected: All checks pass, no errors

**Step 2: Commit**

```bash
git add scenes/player/player.tscn scenes/player/player.gd
git commit -m "feat: add framed camera with drag margins (SCA-29)"
```

**Step 3: Manual verification (delegate to user)**

Open the game and verify:
1. Camera stays still when player moves within the center safe zone
2. Camera smoothly follows when player exits the safe zone
3. Works in all three zones (Tower, Beach, Sea)
