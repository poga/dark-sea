# Milestone 2: Playground Zones & Turret Combat - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split the playable area into tower/beach/sea zones, add turret shooting mechanics, and introduce test monsters.

**Architecture:** Zone-based Area2D system controls drop behavior. Items gain turret attack logic (detection area + timer + projectile spawning). Monsters are simple Area2D nodes that drift left. Collision layers isolate projectile-monster interactions.

**Tech Stack:** Godot 4.6, GDScript, GUT testing framework

---

### Task 1: Configure Collision Layer Names

**Files:**
- Modify: `project.godot`

**Step 1: Add collision layer names to project.godot**

Add under a new `[layer_names]` section:

```ini
[layer_names]

2d_physics/layer_1="player"
2d_physics/layer_2="items"
2d_physics/layer_3="monsters"
2d_physics/layer_4="projectiles"
```

**Step 2: Run validation**

Run: `just check`
Expected: "Project validates successfully"

**Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: configure collision layer names for zones and combat"
```

---

### Task 2: Monster Scene

**Files:**
- Create: `scenes/monster/monster.gd`
- Create: `scenes/monster/monster.tscn`
- Create: `core/tests/test_monster.gd`

**Step 1: Write failing tests**

Create `core/tests/test_monster.gd`:

```gdscript
extends GutTest

var monster: Area2D

func before_each():
	monster = preload("res://scenes/monster/monster.tscn").instantiate()
	add_child_autofree(monster)

func test_initial_hp():
	assert_eq(monster.hp, 30.0)

func test_take_damage_reduces_hp():
	monster.take_damage(10.0)
	assert_eq(monster.hp, 20.0)

func test_take_damage_emits_died_at_zero():
	watch_signals(monster)
	monster.take_damage(30.0)
	assert_signal_emitted(monster, "died")

func test_take_damage_does_not_emit_died_above_zero():
	watch_signals(monster)
	monster.take_damage(10.0)
	assert_signal_not_emitted(monster, "died")

func test_drifts_left():
	var start_x: float = monster.global_position.x
	# Simulate a physics frame
	monster._physics_process(0.1)
	assert_lt(monster.global_position.x, start_x)
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL (scene doesn't exist yet)

**Step 3: Create monster script**

Create `scenes/monster/monster.gd`:

```gdscript
extends Area2D

signal died

@export var hp: float = 30.0
@export var speed: float = 50.0

var _basic_float_label_scene: PackedScene = preload("res://scenes/components/NumberLabel/basic_float_label.tscn")

func _physics_process(delta: float) -> void:
	global_position.x -= speed * delta

func take_damage(amount: float) -> void:
	hp -= amount
	_show_damage_number(amount)
	if hp <= 0:
		died.emit()
		queue_free()

func _show_damage_number(amount: float) -> void:
	var label: Label = _basic_float_label_scene.instantiate()
	label.text = str(int(amount))
	add_child(label)
```

**Step 4: Create monster scene**

Create `scenes/monster/monster.tscn` - an Area2D with:
- Script: `monster.gd`
- Collision layer: 3 (monsters), mask: none
- Child `Sprite2D`: icon.svg, scale 0.3, green tint for visibility
- Child `Label`: "Monster"
- Child `CollisionShape2D`: CircleShape2D radius 15

**Step 5: Run tests to verify they pass**

Run: `just test`
Expected: All monster tests PASS

**Step 6: Run validation**

Run: `just check`
Expected: "Project validates successfully"

**Step 7: Commit**

```bash
git add scenes/monster/ core/tests/test_monster.gd
git commit -m "feat: add monster scene with HP, damage, and leftward drift"
```

---

### Task 3: Projectile Scene

**Files:**
- Create: `scenes/projectile/projectile.gd`
- Create: `scenes/projectile/projectile.tscn`
- Create: `core/tests/test_projectile.gd`

**Step 1: Write failing tests**

Create `core/tests/test_projectile.gd`:

```gdscript
extends GutTest

var projectile: Area2D
var ProjectileScene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

func before_each():
	projectile = ProjectileScene.instantiate()
	add_child_autofree(projectile)

func test_moves_in_direction():
	projectile.direction = Vector2.RIGHT
	projectile.speed = 100.0
	var start_x: float = projectile.global_position.x
	projectile._physics_process(0.1)
	assert_gt(projectile.global_position.x, start_x)

func test_moves_with_speed():
	projectile.direction = Vector2(1, 0)
	projectile.speed = 200.0
	var start_pos: Vector2 = projectile.global_position
	projectile._physics_process(1.0)
	var moved: float = projectile.global_position.distance_to(start_pos)
	assert_almost_eq(moved, 200.0, 1.0)

func test_damage_property():
	projectile.damage = 15.0
	assert_eq(projectile.damage, 15.0)
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL (scene doesn't exist yet)

**Step 3: Create projectile script**

Create `scenes/projectile/projectile.gd`:

```gdscript
extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0
var damage: float = 10.0
var _lifetime: float = 2.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_lifetime -= delta
	if _lifetime <= 0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	queue_free()
```

**Step 4: Create projectile scene**

Create `scenes/projectile/projectile.tscn` - an Area2D with:
- Script: `projectile.gd`
- Collision layer: 4 (projectiles), mask: 3 (monsters only)
- Child `ColorRect`: 8x8, bright yellow, offset to center (-4, -4)
- Child `CollisionShape2D`: RectangleShape2D 8x8

**Step 5: Run tests to verify they pass**

Run: `just test`
Expected: All projectile tests PASS

**Step 6: Run validation**

Run: `just check`
Expected: "Project validates successfully"

**Step 7: Commit**

```bash
git add scenes/projectile/ core/tests/test_projectile.gd
git commit -m "feat: add projectile scene with straight-line movement and damage"
```

---

### Task 4: Zone System

**Files:**
- Create: `scenes/zones/zone.gd`
- Create: `scenes/zones/tower_zone.tscn`
- Create: `scenes/zones/beach_zone.tscn`
- Create: `scenes/zones/sea_zone.tscn`

**Step 1: Create zone script**

Create `scenes/zones/zone.gd`:

```gdscript
extends Area2D

enum ZoneType { TOWER, BEACH, SEA }

@export var zone_type: ZoneType = ZoneType.BEACH
@export var zone_color: Color = Color(0.5, 0.5, 0.5, 0.2)
@export var zone_width: float = 200.0
@export var zone_height: float = 800.0

func _ready() -> void:
	$ColorRect.color = zone_color
	$ColorRect.size = Vector2(zone_width, zone_height)
	$ColorRect.position = Vector2(-zone_width / 2, -zone_height / 2)
	$CollisionShape2D.shape.size = Vector2(zone_width, zone_height)
```

**Step 2: Create tower_zone.tscn**

Area2D scene with:
- Script: `zone.gd`
- `zone_type` = TOWER
- `zone_color` = Color(0.2, 0.6, 0.2, 0.2) (green tint)
- `zone_width` = 200.0
- Collision layer: none, mask: none (zones don't collide physically - player detects them via overlap)
- Child `ColorRect` for background
- Child `CollisionShape2D`: RectangleShape2D
- Child `Label`: "Tower Zone"

**Step 3: Create beach_zone.tscn**

Same structure as tower_zone, but:
- `zone_type` = BEACH
- `zone_color` = Color(0.8, 0.7, 0.4, 0.2) (sand tint)
- `zone_width` = 400.0

**Step 4: Create sea_zone.tscn**

Same structure as tower_zone, but:
- `zone_type` = SEA
- `zone_color` = Color(0.2, 0.4, 0.8, 0.2) (blue tint)
- `zone_width` = 400.0

**Step 5: Run validation**

Run: `just check`
Expected: "Project validates successfully"

**Step 6: Commit**

```bash
git add scenes/zones/
git commit -m "feat: add zone scenes for tower, beach, and sea areas"
```

---

### Task 5: Player Zone-Aware Dropping

**Files:**
- Modify: `scenes/player/player.gd`
- Modify: `scenes/item/item.gd`
- Create: `core/tests/test_zone_dropping.gd`

**Step 1: Write failing tests**

Create `core/tests/test_zone_dropping.gd`:

```gdscript
extends GutTest

var player: CharacterBody2D
var item_scene: PackedScene = preload("res://scenes/item/item.tscn")
var zone_scene: PackedScene = preload("res://scenes/zones/tower_zone.tscn")

func before_each():
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)

func _make_item(pos: Vector2) -> Area2D:
	var item: Area2D = item_scene.instantiate()
	add_child_autofree(item)
	item.global_position = pos
	return item

func _pick_up_item(item: Area2D) -> void:
	player._items_in_range.append(item)
	player.pick_up_nearest_item()

func test_current_zone_initially_null():
	assert_null(player.current_zone)

func test_can_drop_returns_false_when_no_zone():
	assert_false(player.can_drop())

func test_can_drop_returns_true_in_tower_zone():
	var ZoneScript = load("res://scenes/zones/zone.gd")
	player.current_zone = ZoneScript.ZoneType.TOWER
	assert_true(player.can_drop())

func test_can_drop_returns_true_in_beach_zone():
	var ZoneScript = load("res://scenes/zones/zone.gd")
	player.current_zone = ZoneScript.ZoneType.BEACH
	assert_true(player.can_drop())

func test_can_drop_returns_false_in_sea_zone():
	var ZoneScript = load("res://scenes/zones/zone.gd")
	player.current_zone = ZoneScript.ZoneType.SEA
	assert_false(player.can_drop())

func test_drop_in_tower_zone_sets_turret_state():
	var ZoneScript = load("res://scenes/zones/zone.gd")
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	player.current_zone = ZoneScript.ZoneType.TOWER
	player.drop_item()
	assert_eq(item.current_state, item.State.TURRET)

func test_drop_in_beach_zone_keeps_pickup_state():
	var ZoneScript = load("res://scenes/zones/zone.gd")
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	player.current_zone = ZoneScript.ZoneType.BEACH
	player.drop_item()
	assert_eq(item.current_state, item.State.PICKUP)
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL (current_zone, can_drop don't exist yet)

**Step 3: Add `drop_as_pickup()` to item.gd**

Add to `scenes/item/item.gd` after `drop()`:

```gdscript
func drop_as_pickup() -> void:
	current_state = State.PICKUP
	_update_state_visuals()
```

**Step 4: Add zone tracking and zone-aware drop to player.gd**

Modify `scenes/player/player.gd`:

Add preload at top:
```gdscript
const ZoneScript = preload("res://scenes/zones/zone.gd")
```

Add new variable:
```gdscript
var current_zone = null  # ZoneScript.ZoneType or null
```

Add zone tracking methods:
```gdscript
func can_drop() -> bool:
	if current_zone == null:
		return false
	return current_zone != ZoneScript.ZoneType.SEA

func _on_zone_entered(area: Area2D) -> void:
	if area.has_method("_ready") and "zone_type" in area:
		current_zone = area.zone_type

func _on_zone_exited(area: Area2D) -> void:
	if area.has_method("_ready") and "zone_type" in area:
		if current_zone == area.zone_type:
			current_zone = null
```

Modify `_unhandled_input` to check `can_drop()`:
```gdscript
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if held_item:
			if can_drop():
				drop_item()
		else:
			pick_up_nearest_item()
```

Modify `drop_item()` to be zone-aware:
```gdscript
func drop_item():
	var item: Area2D = held_item
	var drop_pos: Vector2 = global_position
	held_item = null
	if current_zone == ZoneScript.ZoneType.TOWER:
		item.drop()
	else:
		item.drop_as_pickup()
	$HoldPosition.remove_child(item)
	get_parent().add_child(item)
	item.global_position = drop_pos
	item_dropped.emit(item, drop_pos)
```

**Step 5: Run tests to verify they pass**

Run: `just test`
Expected: All zone dropping tests PASS, all existing player tests still PASS

**Step 6: Run validation**

Run: `just check`
Expected: "Project validates successfully"

**Step 7: Commit**

```bash
git add scenes/player/player.gd scenes/item/item.gd core/tests/test_zone_dropping.gd
git commit -m "feat: add zone-aware item dropping (tower=turret, beach=pickup, sea=blocked)"
```

---

### Task 6: Turret Attack Behavior

**Files:**
- Modify: `scenes/item/item.gd`
- Modify: `scenes/item/item.tscn`
- Create: `core/tests/test_turret_attack.gd`

**Step 1: Write failing tests**

Create `core/tests/test_turret_attack.gd`:

```gdscript
extends GutTest

var item: Area2D
var monster_scene: PackedScene = preload("res://scenes/monster/monster.tscn")

func before_each():
	item = preload("res://scenes/item/item.tscn").instantiate()
	add_child_autofree(item)

func test_turret_exports_exist():
	assert_eq(item.attack_range, 150.0)
	assert_eq(item.attack_rate, 1.0)
	assert_eq(item.projectile_speed, 300.0)
	assert_eq(item.projectile_damage, 10.0)

func test_detection_area_disabled_in_pickup_state():
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	assert_false(detection.monitoring)

func test_detection_area_enabled_in_turret_state():
	item.drop()
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	assert_true(detection.monitoring)

func test_shoot_timer_stopped_in_pickup_state():
	var timer: Timer = item.get_node("TurretState/ShootTimer")
	assert_true(timer.is_stopped())

func test_shoot_timer_running_in_turret_state():
	item.drop()
	var timer: Timer = item.get_node("TurretState/ShootTimer")
	assert_false(timer.is_stopped())

func test_find_target_returns_null_when_empty():
	item.drop()
	assert_null(item._find_target())

func test_pick_up_stops_turret_systems():
	item.drop()
	item.pick_up()
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	var timer: Timer = item.get_node("TurretState/ShootTimer")
	assert_false(detection.monitoring)
	assert_true(timer.is_stopped())
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL (turret attack exports and nodes don't exist)

**Step 3: Add turret exports and attack logic to item.gd**

Modify `scenes/item/item.gd` to add turret combat. Full updated script:

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

func drop():
	current_state = State.TURRET
	_update_state_visuals()
	_update_turret_systems()
	placed_as_turret.emit()

func drop_as_pickup() -> void:
	current_state = State.PICKUP
	_update_state_visuals()
	_update_turret_systems()

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

func _shoot_at(target: Area2D) -> void:
	var projectile: Area2D = _projectile_scene.instantiate()
	projectile.global_position = global_position
	var dir: Vector2 = (target.global_position - global_position).normalized()
	projectile.direction = dir
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	get_tree().current_scene.add_child(projectile)

func _update_state_visuals():
	$PickupState.visible = current_state == State.PICKUP
	$TurretState.visible = current_state == State.TURRET

func _update_turret_systems() -> void:
	var active: bool = current_state == State.TURRET
	$TurretState/DetectionArea.monitoring = active
	if active:
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
	# Clean up dead references
	_monsters_in_range = _monsters_in_range.filter(func(m): return is_instance_valid(m))
	var target: Area2D = _find_target()
	if target:
		_shoot_at(target)
```

**Step 4: Update item.tscn**

Add to TurretState node in `scenes/item/item.tscn`:
- Child `DetectionArea` (Area2D):
  - collision layer: none, mask: 3 (monsters)
  - monitoring: false (starts disabled)
  - Child `CollisionShape2D`: CircleShape2D radius 150 (matches attack_range default)
- Child `ShootTimer` (Timer):
  - wait_time: 1.0
  - one_shot: false
  - autostart: false

**Step 5: Run tests to verify they pass**

Run: `just test`
Expected: All turret attack tests PASS, all existing item tests still PASS

**Step 6: Run validation**

Run: `just check`
Expected: "Project validates successfully"

**Step 7: Commit**

```bash
git add scenes/item/item.gd scenes/item/item.tscn core/tests/test_turret_attack.gd
git commit -m "feat: add turret attack behavior with detection, targeting, and projectile spawning"
```

---

### Task 7: Main Scene Composition

**Files:**
- Modify: `scenes/game/main.tscn`
- Create: `scenes/game/test_spawner.gd`

**Step 1: Create test spawner script**

Create `scenes/game/test_spawner.gd`:

```gdscript
extends Node2D

@export var spawn_interval: float = 3.0
@export var spawn_x: float = 400.0
@export var spawn_y_min: float = -300.0
@export var spawn_y_max: float = 300.0

var _monster_scene: PackedScene = preload("res://scenes/monster/monster.tscn")

func _ready() -> void:
	$SpawnTimer.wait_time = spawn_interval
	$SpawnTimer.start()
	$SpawnTimer.timeout.connect(_on_spawn_timer_timeout)

func _on_spawn_timer_timeout() -> void:
	var monster: Area2D = _monster_scene.instantiate()
	var spawn_y: float = randf_range(spawn_y_min, spawn_y_max)
	monster.global_position = Vector2(spawn_x, spawn_y)
	get_parent().get_node("Monsters").add_child(monster)
```

**Step 2: Update main.tscn**

Rebuild `scenes/game/main.tscn` with full composition:

```
Main (Node2D)
├── Zones (Node2D)
│   ├── TowerZone (instance, position: -400, 0)
│   ├── BeachZone (instance, position: 0, 0)
│   └── SeaZone (instance, position: 400, 0)
├── Player (instance, position: 0, 0)
│   [connect PickupZone to also detect zones]
├── Items (Node2D)
│   ├── Item1 (instance, position: 200, 0)  [in sea - player must collect]
│   ├── Item2 (instance, position: 300, 100)
│   └── Item3 (instance, position: 250, -200)
├── Monsters (Node2D)
└── TestSpawner (Node2D, script: test_spawner.gd)
    └── SpawnTimer (Timer)
```

Zone positions are arranged so:
- TowerZone: left edge (x ~ -400)
- BeachZone: center (x ~ 0)
- SeaZone: right side (x ~ 400)
- Items start in sea zone for pickup

The player's `PickupZone` (Area2D) needs to also detect zone Area2Ds. Add zone detection by connecting to the zone's `body_entered` or by having the player's CharacterBody2D detected by zone Area2Ds. Since zones are Area2D and Player is CharacterBody2D, use each zone's `body_entered`/`body_exited` signals connected to player's `_on_zone_entered`/`_on_zone_exited` methods in the main scene's signal connections.

**Step 3: Run validation**

Run: `just check`
Expected: "Project validates successfully"

**Step 4: Manual testing**

Run the game and verify:
- Three zones visible with different colors
- Player can pick up items from sea zone
- Dropping in tower zone activates turret (red tint)
- Dropping on beach keeps pickup state
- Cannot drop in sea zone
- Turrets shoot at spawned monsters
- Projectiles hit monsters and show damage numbers
- Monsters drift left and die

**Step 5: Commit**

```bash
git add scenes/game/ scenes/zones/
git commit -m "feat: compose main scene with zones, test spawner, and full turret combat"
```

---

## Task Dependency Order

```
Task 1 (collision layers) ─┐
Task 2 (monster) ───────────┤
Task 3 (projectile) ────────┼─→ Task 6 (turret attack) ─→ Task 7 (main scene)
Task 4 (zones) ─────────────┤
Task 5 (zone dropping) ─────┘
```

Tasks 1-4 can be done in parallel. Task 5 depends on Task 4. Task 6 depends on Tasks 2+3. Task 7 depends on all others.
