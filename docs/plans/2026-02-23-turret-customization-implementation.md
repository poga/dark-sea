# Turret Behavior Customization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor item.gd into an extensible base class so designers can create custom turret types by extending it.

**Architecture:** Rename item.gd → base_item.gd. Extract virtual methods (_find_target, _attack, _on_turret_activated, _on_turret_deactivated). Existing behavior becomes the default implementation. Prove the pattern by creating one example custom item.

**Tech Stack:** Godot 4.6, GDScript, GUT testing framework

---

### Task 1: Rename item.gd to base_item.gd and add virtual methods

**Files:**
- Rename: `scenes/item/item.gd` → `scenes/item/base_item.gd`
- Modify: `scenes/item/base_item.gd`
- Modify: `scenes/item/item.tscn`

**Step 1: Rename the file with git**

```bash
git mv scenes/item/item.gd scenes/item/base_item.gd
```

**Step 2: Update item.tscn to reference the new script path**

In `scenes/item/item.tscn`, change:
```
[ext_resource type="Script" path="res://scenes/item/item.gd" id="1"]
```
to:
```
[ext_resource type="Script" path="res://scenes/item/base_item.gd" id="1"]
```

**Step 3: Refactor base_item.gd**

Rename `_shoot_at()` to `_attack()`. Add empty virtual lifecycle hooks. Call hooks from state transitions. Update `_on_shoot_timer_timeout` to call `_attack()`.

Full updated `scenes/item/base_item.gd`:

```gdscript
extends Area2D

signal picked_up_as_item
signal picked_up_as_turret
signal placed_as_turret

enum State { PICKUP, TURRET }

@export var item_name: String = "Item"
@export var attack_range: float = 150.0
@export var attack_rate: float = 1.0
@export var projectile_speed: float = 300.0
@export var projectile_damage: float = 10.0

var current_state: State = State.PICKUP
var _monsters_in_range: Array[Area2D] = []
var _projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

func _ready():
	$PickupState/Label.text = item_name
	$TurretState/Label.text = item_name
	$TurretState/DetectionArea.area_entered.connect(_on_detection_area_entered)
	$TurretState/DetectionArea.area_exited.connect(_on_detection_area_exited)
	$TurretState/ShootTimer.timeout.connect(_on_shoot_timer_timeout)
	_update_state_visuals()
	_update_turret_systems()

func pick_up():
	if current_state == State.PICKUP:
		picked_up_as_item.emit()
	else:
		picked_up_as_turret.emit()
	current_state = State.PICKUP
	_monsters_in_range.clear()
	_update_state_visuals()
	_update_turret_systems()
	_on_turret_deactivated()

func drop():
	current_state = State.TURRET
	_update_state_visuals()
	_update_turret_systems()
	_on_turret_activated()
	placed_as_turret.emit()

func drop_as_pickup() -> void:
	current_state = State.PICKUP
	_update_state_visuals()
	_update_turret_systems()

# --- Virtual methods: override in custom items ---

func _find_target() -> Area2D:
	if _monsters_in_range.is_empty():
		return null
	var closest: Area2D = null
	var closest_dist: float = INF
	for monster in _monsters_in_range:
		if not is_instance_valid(monster):
			continue
		var dist: float = global_position.distance_to(monster.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = monster
	return closest

func _attack(target: Area2D) -> void:
	var projectile: Area2D = _projectile_scene.instantiate()
	projectile.global_position = global_position
	var dir: Vector2 = (target.global_position - global_position).normalized()
	projectile.direction = dir
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	get_tree().current_scene.add_child(projectile)

func _on_turret_activated() -> void:
	pass

func _on_turret_deactivated() -> void:
	pass

# --- Internal methods ---

func _update_state_visuals():
	$PickupState.visible = current_state == State.PICKUP
	$TurretState.visible = current_state == State.TURRET

func _update_turret_systems() -> void:
	var active: bool = current_state == State.TURRET
	$TurretState/DetectionArea.monitoring = active
	if active:
		$TurretState/DetectionArea/CollisionShape2D.shape.radius = attack_range
		$TurretState/ShootTimer.wait_time = 1.0 / attack_rate
		$TurretState/ShootTimer.start()
	else:
		$TurretState/ShootTimer.stop()

func _on_detection_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		_monsters_in_range.append(area)

func _on_detection_area_exited(area: Area2D) -> void:
	_monsters_in_range.erase(area)

func _on_shoot_timer_timeout() -> void:
	_monsters_in_range = _monsters_in_range.filter(func(m): return is_instance_valid(m))
	var target: Area2D = _find_target()
	if target:
		_attack(target)
```

**Step 4: Run tests to verify nothing broke**

Run: `just test`
Expected: All 45 tests PASS (tests preload `item.tscn`, which now points to `base_item.gd`)

**Step 5: Run validation**

Run: `just check`
Expected: "Project validates successfully"

**Step 6: Commit**

```bash
git add scenes/item/base_item.gd scenes/item/item.tscn
git commit -m "refactor: rename item.gd to base_item.gd with virtual attack methods

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Create an example custom item to prove the pattern

**Files:**
- Create: `scenes/item/aoe_item.gd`
- Create: `scenes/item/aoe_item.tscn` (duplicate of item.tscn with new script)
- Create: `core/tests/test_aoe_item.gd`
- Modify: `scenes/game/main.tscn` (add one AOE item to test)

**Step 1: Write failing tests**

Create `core/tests/test_aoe_item.gd`:

```gdscript
extends GutTest

var item: Area2D

func before_each():
	item = preload("res://scenes/item/aoe_item.tscn").instantiate()
	add_child_autofree(item)

func test_inherits_base_item_state():
	assert_eq(item.current_state, item.State.PICKUP)

func test_has_custom_export():
	assert_true(item.explosion_radius > 0)

func test_inherits_base_exports():
	assert_eq(item.attack_range, 150.0)
	assert_eq(item.attack_rate, 1.0)

func test_drop_activates_turret():
	item.drop()
	assert_eq(item.current_state, item.State.TURRET)
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	assert_true(detection.monitoring)

func test_pick_up_deactivates_turret():
	item.drop()
	item.pick_up()
	assert_eq(item.current_state, item.State.PICKUP)
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL (scene doesn't exist yet)

**Step 3: Create the AOE item script**

Create `scenes/item/aoe_item.gd`:

```gdscript
extends "res://scenes/item/base_item.gd"

@export var explosion_radius: float = 80.0

func _attack(target: Area2D) -> void:
	for monster in _monsters_in_range:
		if is_instance_valid(monster):
			monster.take_damage(projectile_damage)
```

**Step 4: Create the AOE item scene**

Duplicate `scenes/item/item.tscn` as `scenes/item/aoe_item.tscn`. Change:
- Script reference: `res://scenes/item/aoe_item.gd`
- TurretState Sprite2D modulate: `Color(0.5, 0.5, 1, 1)` (blue tint to distinguish from default red)
- PickupState Label text: "AOE Item"
- TurretState Label text: "AOE Turret"
- item_name export: "AOE Item"

The .tscn:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scenes/item/aoe_item.gd" id="1"]
[ext_resource type="Texture2D" path="res://icon.svg" id="2"]

[sub_resource type="CircleShape2D" id="SubResource_1"]
radius = 20.0

[sub_resource type="CircleShape2D" id="SubResource_2"]
radius = 150.0

[node name="Item" type="Area2D"]
script = ExtResource("1")
item_name = "AOE Item"

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
text = "AOE Item"

[node name="TurretState" type="Node2D" parent="."]
visible = false

[node name="Sprite2D" type="Sprite2D" parent="TurretState"]
texture = ExtResource("2")
scale = Vector2(0.5, 0.5)
modulate = Color(0.5, 0.5, 1, 1)

[node name="Label" type="Label" parent="TurretState"]
offset_left = -40.0
offset_top = -55.0
offset_right = 40.0
offset_bottom = -35.0
horizontal_alignment = 1
text = "AOE Turret"

[node name="DetectionArea" type="Area2D" parent="TurretState"]
collision_layer = 0
collision_mask = 4
monitoring = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="TurretState/DetectionArea"]
shape = SubResource("SubResource_2")

[node name="ShootTimer" type="Timer" parent="TurretState"]
wait_time = 1.0
one_shot = false
autostart = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SubResource_1")
```

**Step 5: Add one AOE item to main.tscn**

Add to `scenes/game/main.tscn` under the Items node:

```
[ext_resource type="PackedScene" path="res://scenes/item/aoe_item.tscn" id="7"]

[node name="AoeItem1" parent="Items" instance=ExtResource("7")]
position = Vector2(350, 50)
```

Update load_steps to 8.

**Step 6: Run tests to verify they pass**

Run: `just test`
Expected: All tests PASS (existing 45 + 5 new)

**Step 7: Run validation**

Run: `just check`
Expected: "Project validates successfully"

**Step 8: Commit**

```bash
git add scenes/item/aoe_item.gd scenes/item/aoe_item.tscn core/tests/test_aoe_item.gd scenes/game/main.tscn
git commit -m "feat: add AOE item as example custom turret type

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task Dependency Order

```
Task 1 (refactor base_item) → Task 2 (example AOE item)
```

Sequential - Task 2 depends on Task 1.
