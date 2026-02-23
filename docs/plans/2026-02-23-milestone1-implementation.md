# Milestone 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Controllable 2D character with WASD movement and item pickup/drop mechanics.

**Architecture:** Item scene (Area2D) with two state nodes (PickupState/TurretState) toggled by visibility. Player scene (CharacterBody2D) detects items via Area2D overlap, reparents items between world and HoldPosition. Camera2D follows player via parenting.

**Tech Stack:** Godot 4.6, GDScript, GUT testing framework

---

### Task 1: Add input map to project.godot

**Files:**
- Modify: `project.godot`

**Step 1: Add input actions**

Add an `[input]` section to `project.godot` before the `[rendering]` section with these 5 actions:

```ini
[input]

move_up={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"location":0,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
]
}
interact={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
]
}
```

Physical keycodes: W=87, S=83, A=65, D=68, Space=32.

**Step 2: Validate**

Run: `just check`
Expected: "Project validates successfully"

**Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: add WASD and interact input actions"
```

---

### Task 2: Create item script and tests (TDD)

**Files:**
- Create: `scenes/item/item.gd`
- Create: `core/tests/test_item.gd`

**Step 1: Write the item script**

Create `scenes/item/item.gd`:

```gdscript
extends Area2D

signal picked_up_as_item
signal picked_up_as_turret
signal placed_as_turret

enum State { PICKUP, TURRET }

@export var item_name: String = "Item"

var current_state: State = State.PICKUP

func _ready():
	$PickupState/Label.text = item_name
	$TurretState/Label.text = item_name
	_update_state_visuals()

func pick_up():
	if current_state == State.PICKUP:
		picked_up_as_item.emit()
	else:
		picked_up_as_turret.emit()
	current_state = State.PICKUP
	_update_state_visuals()

func drop():
	current_state = State.TURRET
	_update_state_visuals()
	placed_as_turret.emit()

func _update_state_visuals():
	$PickupState.visible = current_state == State.PICKUP
	$TurretState.visible = current_state == State.TURRET
```

**Step 2: Write the failing tests**

Create `core/tests/test_item.gd`:

```gdscript
extends GutTest

var item: Area2D

func before_each():
	item = preload("res://scenes/item/item.tscn").instantiate()
	add_child_autofree(item)

func test_initial_state_is_pickup():
	assert_eq(item.current_state, item.State.PICKUP)
	assert_true(item.get_node("PickupState").visible)
	assert_false(item.get_node("TurretState").visible)

func test_item_name_sets_labels():
	assert_eq(item.get_node("PickupState/Label").text, "Item")
	assert_eq(item.get_node("TurretState/Label").text, "Item")

func test_pick_up_from_pickup_emits_picked_up_as_item():
	watch_signals(item)
	item.pick_up()
	assert_signal_emitted(item, "picked_up_as_item")

func test_drop_switches_to_turret_state():
	item.drop()
	assert_eq(item.current_state, item.State.TURRET)
	assert_false(item.get_node("PickupState").visible)
	assert_true(item.get_node("TurretState").visible)

func test_drop_emits_placed_as_turret():
	watch_signals(item)
	item.drop()
	assert_signal_emitted(item, "placed_as_turret")

func test_pick_up_from_turret_emits_picked_up_as_turret():
	item.drop()
	watch_signals(item)
	item.pick_up()
	assert_signal_emitted(item, "picked_up_as_turret")

func test_pick_up_from_turret_returns_to_pickup_state():
	item.drop()
	item.pick_up()
	assert_eq(item.current_state, item.State.PICKUP)
	assert_true(item.get_node("PickupState").visible)
	assert_false(item.get_node("TurretState").visible)
```

Tests will fail until the scene file is created (Task 3).

**Step 3: Commit script and tests**

```bash
git add scenes/item/item.gd core/tests/test_item.gd
git commit -m "feat: add item script and tests (scene pending)"
```

---

### Task 3: Create item scene file

**Files:**
- Create: `scenes/item/item.tscn`

**Step 1: Create the scene**

Create `scenes/item/item.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/item/item.gd" id="1"]
[ext_resource type="Texture2D" path="res://icon.svg" id="2"]

[sub_resource type="CircleShape2D" id="SubResource_1"]
radius = 20.0

[node name="Item" type="Area2D"]
script = ExtResource("1")

[node name="PickupState" type="Node2D" parent="."]

[node name="Sprite2D" type="Sprite2D" parent="PickupState"]
texture = ExtResource("2")
scale = Vector2(0.5, 0.5)

[node name="Label" type="Label" parent="PickupState"]
offset_left = -40.0
offset_top = -55.0
offset_right = 40.0
offset_bottom = -35.0
horizontal_alignment = 1
text = "Item"

[node name="TurretState" type="Node2D" parent="."]
visible = false

[node name="Sprite2D" type="Sprite2D" parent="TurretState"]
texture = ExtResource("2")
scale = Vector2(0.5, 0.5)
modulate = Color(1, 0.5, 0.5, 1)

[node name="Label" type="Label" parent="TurretState"]
offset_left = -40.0
offset_top = -55.0
offset_right = 40.0
offset_bottom = -35.0
horizontal_alignment = 1
text = "Turret"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SubResource_1")
```

Key details:
- PickupState: normal icon with "Item" label above
- TurretState: red-tinted icon with "Turret" label above, hidden by default
- CollisionShape2D: circle radius 20px for Area2D detection
- Sprite scale 0.5 (icon.svg is 128x128, renders at 64x64)

**Step 2: Run tests**

Run: `just test`
Expected: All 7 item tests pass.

**Step 3: Validate**

Run: `just check`
Expected: "Project validates successfully"

**Step 4: Commit**

```bash
git add scenes/item/item.tscn
git commit -m "feat: add item scene with pickup/turret state visuals"
```

---

### Task 4: Create player script and tests (TDD)

**Files:**
- Create: `scenes/player/player.gd`
- Create: `core/tests/test_player.gd`

**Step 1: Write the player script**

Create `scenes/player/player.gd`:

```gdscript
extends CharacterBody2D

signal item_picked_up(item: Area2D)
signal item_dropped(item: Area2D, drop_position: Vector2)

@export var speed: float = 200.0

var held_item: Area2D = null
var _items_in_range: Array[Area2D] = []

func _ready():
	$PickupZone.area_entered.connect(_on_pickup_zone_area_entered)
	$PickupZone.area_exited.connect(_on_pickup_zone_area_exited)

func _physics_process(_delta):
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if held_item:
			drop_item()
		else:
			pick_up_nearest_item()

func get_nearest_item() -> Area2D:
	if _items_in_range.is_empty():
		return null
	var nearest: Area2D = null
	var nearest_distance: float = INF
	for item in _items_in_range:
		var distance: float = global_position.distance_to(item.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = item
	return nearest

func pick_up_nearest_item():
	var nearest: Area2D = get_nearest_item()
	if nearest == null:
		return
	held_item = nearest
	_items_in_range.erase(nearest)
	nearest.pick_up()
	nearest.get_parent().remove_child(nearest)
	$HoldPosition.add_child(nearest)
	nearest.position = Vector2.ZERO
	item_picked_up.emit(nearest)

func drop_item():
	var item: Area2D = held_item
	var drop_pos: Vector2 = global_position
	held_item = null
	item.drop()
	$HoldPosition.remove_child(item)
	get_parent().add_child(item)
	item.global_position = drop_pos
	item_dropped.emit(item, drop_pos)

func _on_pickup_zone_area_entered(area: Area2D):
	if area != held_item:
		_items_in_range.append(area)

func _on_pickup_zone_area_exited(area: Area2D):
	_items_in_range.erase(area)
```

Key design decisions:
- `get_nearest_item()` is a public method for testability
- `pick_up_nearest_item()` and `drop_item()` are public so tests (and future code) can call them directly
- Reparenting: picked-up items move to `$HoldPosition`; dropped items reparent to `get_parent()` (the main scene)
- `_items_in_range` filtering: `area_entered` ignores the held item; `area_exited` erases silently (no error if not found)

**Step 2: Write the tests**

Create `core/tests/test_player.gd`:

```gdscript
extends GutTest

var player: CharacterBody2D
var item_scene: PackedScene = preload("res://scenes/item/item.tscn")

func before_each():
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)

func _make_item(pos: Vector2) -> Area2D:
	var item: Area2D = item_scene.instantiate()
	add_child_autofree(item)
	item.global_position = pos
	return item

func test_no_held_item_initially():
	assert_null(player.held_item)

func test_get_nearest_item_returns_null_when_empty():
	assert_null(player.get_nearest_item())

func test_get_nearest_item_returns_closest():
	var far_item: Area2D = _make_item(Vector2(200, 0))
	var near_item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range = [far_item, near_item]
	assert_eq(player.get_nearest_item(), near_item)

func test_pick_up_sets_held_item():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range = [item]
	player.pick_up_nearest_item()
	assert_eq(player.held_item, item)

func test_pick_up_emits_signal():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range = [item]
	watch_signals(player)
	player.pick_up_nearest_item()
	assert_signal_emitted(player, "item_picked_up")

func test_pick_up_reparents_to_hold_position():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range = [item]
	player.pick_up_nearest_item()
	assert_eq(item.get_parent(), player.get_node("HoldPosition"))

func test_pick_up_removes_from_items_in_range():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range = [item]
	player.pick_up_nearest_item()
	assert_false(player._items_in_range.has(item))

func test_drop_clears_held_item():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range = [item]
	player.pick_up_nearest_item()
	player.drop_item()
	assert_null(player.held_item)

func test_drop_emits_signal():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range = [item]
	player.pick_up_nearest_item()
	watch_signals(player)
	player.drop_item()
	assert_signal_emitted(player, "item_dropped")

func test_drop_reparents_to_world():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range = [item]
	player.pick_up_nearest_item()
	player.drop_item()
	assert_eq(item.get_parent(), player.get_parent())

func test_pick_up_does_nothing_when_no_items():
	player.pick_up_nearest_item()
	assert_null(player.held_item)
```

Note: WASD movement and Area2D physics detection are delegated to manual verification (per CLAUDE.md: "delegate to manual verification when needed"). These tests cover the pickup/drop logic and signal emission.

**Step 3: Commit**

```bash
git add scenes/player/player.gd core/tests/test_player.gd
git commit -m "feat: add player script and tests (scene pending)"
```

---

### Task 5: Create player scene file

**Files:**
- Create: `scenes/player/player.tscn`

**Step 1: Create the scene**

Create `scenes/player/player.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scenes/player/player.gd" id="1"]
[ext_resource type="Texture2D" path="res://icon.svg" id="2"]

[sub_resource type="RectangleShape2D" id="SubResource_1"]
size = Vector2(32, 32)

[sub_resource type="CircleShape2D" id="SubResource_2"]
radius = 50.0

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2")
scale = Vector2(0.5, 0.5)

[node name="Label" type="Label" parent="."]
offset_left = -40.0
offset_top = -55.0
offset_right = 40.0
offset_bottom = -35.0
horizontal_alignment = 1
text = "Player"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SubResource_1")

[node name="PickupZone" type="Area2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="PickupZone"]
shape = SubResource("SubResource_2")

[node name="HoldPosition" type="Marker2D" parent="."]
position = Vector2(0, -60)

[node name="Camera2D" type="Camera2D" parent="."]
position_smoothing_enabled = true
position_smoothing_speed = 5.0
```

Key details:
- CollisionShape2D: 32x32 rectangle (half the 64px rendered sprite)
- PickupZone: 50px radius circle — items within this range can be picked up
- HoldPosition: 60px above player center (above the sprite)
- Camera2D: smoothing enabled at speed 5.0

**Step 2: Run tests**

Run: `just test`
Expected: All item and player tests pass.

**Step 3: Validate**

Run: `just check`
Expected: "Project validates successfully"

**Step 4: Commit**

```bash
git add scenes/player/player.tscn
git commit -m "feat: add player scene with pickup zone and camera"
```

---

### Task 6: Update main scene

**Files:**
- Modify: `scenes/game/main.tscn`

**Step 1: Replace main scene contents**

Replace `scenes/game/main.tscn` with:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="1"]
[ext_resource type="PackedScene" path="res://scenes/item/item.tscn" id="2"]

[node name="Main" type="Node2D"]

[node name="Player" parent="." instance=ExtResource("1")]

[node name="Items" type="Node2D" parent="."]

[node name="Item1" parent="Items" instance=ExtResource("2")]
position = Vector2(200, 0)

[node name="Item2" parent="Items" instance=ExtResource("2")]
position = Vector2(-150, 100)

[node name="Item3" parent="Items" instance=ExtResource("2")]
position = Vector2(100, -200)
```

Three test items placed at different positions around the player for testing pickup/drop mechanics.

**Step 2: Validate**

Run: `just check`
Expected: "Project validates successfully"

**Step 3: Commit**

```bash
git add scenes/game/main.tscn
git commit -m "feat: compose main scene with player and test items"
```

---

### Task 7: Final validation and manual testing

**Step 1: Run all tests**

Run: `just test`
Expected: All tests pass (item + player + game_manager).

**Step 2: Validate project**

Run: `just check`
Expected: "Project validates successfully"

**Step 3: Manual verification checklist**

Open the project in Godot editor and run the main scene (F5). Verify:

- [ ] Player renders with Godot icon and "Player" label
- [ ] WASD moves the player in 4/8 directions
- [ ] Camera follows the player smoothly
- [ ] Three items visible with Godot icon and "Item" labels
- [ ] Press Space near an item: item appears above player head
- [ ] Press Space while holding: item drops at player position with red tint and "Turret" label
- [ ] Press Space near a dropped turret: picks it back up
- [ ] Press Space with no items nearby: nothing happens

**Step 4: Commit any fixes, then final commit**

```bash
git add -A
git commit -m "feat: milestone 1 complete - character movement and item pickup"
```
