# Pickup Tween to Toolbar — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When an item is picked up, a visual sprite clone tweens from the item's world position to the toolbar slot in screen space, giving juicy pickup feedback.

**Architecture:** GameManager emits a new `pickup_tween_requested` signal with the icon texture, screen position, and target slot. A new `PickupTweenLayer` Control node (child of UI CanvasLayer) listens to this signal, spawns a TextureRect clone, and tweens it to the toolbar slot center using `TRANS_BACK` + `EASE_OUT`. Toolbar exposes a `get_slot_center()` method for the target position.

**Tech Stack:** GDScript, Godot 4 Tween API, GUT testing framework

---

### Task 1: Add `pickup_tween_requested` signal and emit from `try_pickup`

**Files:**
- Modify: `core/game_manager.gd:1-12` (add signal declaration)
- Modify: `core/game_manager.gd:85-96` (modify `try_pickup` to capture screen pos and emit)
- Test: `core/tests/test_game_manager.gd`

**Step 1: Write the failing test**

Add to `core/tests/test_game_manager.gd`:

```gdscript
func test_try_pickup_emits_pickup_tween_requested():
	# Create a parent to hold the item (try_pickup calls item.get_parent().remove_child)
	var parent := Node2D.new()
	add_child(parent)
	var item := Area2D.new()
	item.set_script(load("res://scenes/item/base_item.gd"))
	item.inventory_icon = load("res://icon.svg")
	parent.add_child(item)
	item.global_position = Vector2(100, 200)

	GameManager.reset_inventory()
	watch_signals(GameManager)
	GameManager.try_pickup(item)

	assert_signal_emitted(GameManager, "pickup_tween_requested")
	parent.queue_free()
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL — signal "pickup_tween_requested" does not exist on GameManager

**Step 3: Add signal declaration and emit in `try_pickup`**

In `core/game_manager.gd`, add after the `item_use_failed` signal (line 12):

```gdscript
signal pickup_tween_requested(texture: Texture2D, screen_pos: Vector2, slot: int)
```

In `try_pickup()`, before `item.get_parent().remove_child(item)` (line 89), capture the screen position. Then emit the signal after `inventory_changed.emit()`. The full updated method:

```gdscript
func try_pickup(item: Area2D) -> bool:
	var slot: int = _find_empty_slot()
	if slot == -1:
		return false
	var screen_pos: Vector2 = _world_to_screen(item.global_position)
	var icon: Texture2D = item.inventory_icon if item.has("inventory_icon") else null
	item.get_parent().remove_child(item)
	item.store_in_inventory()
	inventory[slot] = item
	if slot == active_slot and _player:
		_player.get_node("HoldPosition").add_child(item)
		item.position = Vector2.ZERO
	inventory_changed.emit(slot, item)
	if icon:
		pickup_tween_requested.emit(icon, screen_pos, slot)
	return true
```

Add the helper method at the bottom of the inventory section:

```gdscript
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	return canvas_transform * world_pos
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add core/game_manager.gd core/tests/test_game_manager.gd
git commit -m "feat(pickup-tween): add pickup_tween_requested signal to GameManager"
```

---

### Task 2: Add `get_slot_center` method to Toolbar

**Files:**
- Modify: `scenes/ui/toolbar.gd` (add public method)

**Step 1: Write the implementation**

Add to the end of `scenes/ui/toolbar.gd`:

```gdscript
func get_slot_center(slot: int) -> Vector2:
	if slot < 0 or slot >= _icons.size():
		return Vector2.ZERO
	var icon: TextureRect = _icons[slot]
	return icon.global_position + icon.size / 2.0
```

This returns the global position (in screen/UI coords) of the center of the icon TextureRect for the given slot.

**Step 2: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 3: Commit**

```bash
git add scenes/ui/toolbar.gd
git commit -m "feat(toolbar): add get_slot_center method for tween targeting"
```

---

### Task 3: Create PickupTweenLayer scene and script

**Files:**
- Create: `scenes/ui/pickup_tween_layer.gd`
- Create: `scenes/ui/pickup_tween_layer.tscn`

**Step 1: Create the script**

Create `scenes/ui/pickup_tween_layer.gd`:

```gdscript
extends Control

@export var duration: float = 0.35
@export var icon_size: Vector2 = Vector2(32, 32)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.pickup_tween_requested.connect(_on_pickup_tween_requested)

func _on_pickup_tween_requested(texture: Texture2D, screen_pos: Vector2, slot: int) -> void:
	var toolbar: HBoxContainer = _find_toolbar()
	if toolbar == null:
		return
	var target_pos: Vector2 = toolbar.get_slot_center(slot)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	icon.position = screen_pos - icon_size / 2.0
	add_child(icon)

	var tween: Tween = create_tween()
	tween.tween_property(icon, "position", target_pos - icon_size / 2.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(icon.queue_free)

func _find_toolbar() -> HBoxContainer:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is HBoxContainer and child.has_method("get_slot_center"):
			return child
	return null
```

**Step 2: Create the scene file**

Create `scenes/ui/pickup_tween_layer.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/pickup_tween_layer.gd" id="1"]

[node name="PickupTweenLayer" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1")
```

Note: `mouse_filter = 2` is `MOUSE_FILTER_IGNORE` so the layer doesn't block input.

**Step 3: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 4: Commit**

```bash
git add scenes/ui/pickup_tween_layer.gd scenes/ui/pickup_tween_layer.tscn
git commit -m "feat(pickup-tween): add PickupTweenLayer scene for flying icon effect"
```

---

### Task 4: Wire PickupTweenLayer into main scene

**Files:**
- Modify: `scenes/game/main.tscn` (add PickupTweenLayer as child of UI CanvasLayer)

**Step 1: Add the scene instance to main.tscn**

In `scenes/game/main.tscn`, add a new ext_resource for the pickup tween layer scene, then add it as a child of the UI node (after Toolbar).

Add to ext_resources section:

```
[ext_resource type="PackedScene" path="res://scenes/ui/pickup_tween_layer.tscn" id="17"]
```

Add node after the Toolbar node:

```
[node name="PickupTweenLayer" parent="UI" instance=ExtResource("17")]
```

**Step 2: Run validation**

Run: `just check`
Expected: Project validates successfully (tests pass, project validates)

**Step 3: Manual verification**

Run the game and pick up items. Verify:
- A sprite icon flies from the item's world position to the toolbar slot
- The tween has a juicy overshoot feel (TRANS_BACK)
- No scaling — just position movement
- The icon disappears after landing
- Game logic (inventory, toolbar icon update) still works correctly
- Picking up multiple items in quick succession works without issues

**Step 4: Commit**

```bash
git add scenes/game/main.tscn
git commit -m "feat(pickup-tween): wire PickupTweenLayer into main scene"
```
