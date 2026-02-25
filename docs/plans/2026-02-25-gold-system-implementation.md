# Gold System Implementation Plan (SCA-25)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add gold as an auto-collectible currency that spawns during day and drops from killed monsters.

**Architecture:** Gold is a simple Area2D pickup scene. GameManager holds gold state with signals. A separate GoldSpawner handles daytime spawning and zone-based night cleanup. MonsterSpawner (renamed from test_spawner) spawns gold on monster death. All gold nodes join a "gold" group for easy global tracking.

**Tech Stack:** Godot 4.6, GDScript, GUT test framework

**Collision layer reference:**
- Layer 1: player (CharacterBody2D default)
- Layer 2: items
- Layer 3: monsters
- Layer 4: projectiles

**Key note on collision:** Player's PickupZone (Area2D, default layer 1/mask 1) detects all Area2Ds on layer 1 via `area_entered`. Gold will also be on layer 1 (default), so PickupZone WILL fire `area_entered` for gold. Player script must filter gold out with a `has_method("pick_up")` check.

---

### Task 1: Add gold state to GameManager

**Files:**
- Modify: `core/game_manager.gd:1-6` (add signal and var)
- Modify: `core/game_manager.gd` (add method at end)
- Test: `core/tests/test_game_manager.gd`

**Step 1: Write failing tests**

Add to `core/tests/test_game_manager.gd`:

```gdscript
func before_each() -> void:
	GameManager.gold = 0

func test_add_gold_increases_gold():
	GameManager.add_gold(5)
	assert_eq(GameManager.gold, 5)

func test_add_gold_emits_gold_changed():
	watch_signals(GameManager)
	GameManager.add_gold(3)
	assert_signal_emitted_with_parameters(GameManager, "gold_changed", [3])

func test_add_gold_accumulates():
	GameManager.add_gold(2)
	GameManager.add_gold(3)
	assert_eq(GameManager.gold, 5)
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `gold` property and `add_gold` method don't exist, `gold_changed` signal not defined.

**Step 3: Implement gold state in GameManager**

In `core/game_manager.gd`, add signal on line 4 (after `signal phase_changed`):

```gdscript
signal gold_changed(new_amount: int)
```

Add var on line 12 (after `var current_phase`):

```gdscript
var gold: int = 0
```

Add method at end of file:

```gdscript
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
```

**Step 4: Run tests to verify they pass**

Run: `just test`
Expected: All new gold tests PASS. All existing tests still PASS.

**Step 5: Commit**

```bash
git add core/game_manager.gd core/tests/test_game_manager.gd
git commit -m "feat: add gold state and signal to GameManager"
```

---

### Task 2: Create gold pickup scene

**Files:**
- Create: `scenes/gold/gold.gd`
- Create: `scenes/gold/gold.tscn`
- Modify: `scenes/player/player.gd:75-79` (filter PickupZone)

**Step 1: Write the gold script**

Create `scenes/gold/gold.gd`:

```gdscript
extends Area2D

@export var value: int = 1

func _ready() -> void:
	add_to_group("gold")
	body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node2D) -> void:
	GameManager.add_gold(value)
	queue_free()
```

Notes:
- `body_entered` detects the Player's CharacterBody2D (both on layer 1).
- `add_to_group("gold")` enables global tracking for cleanup.
- No need to check body type — only the player CharacterBody2D will trigger body_entered in practice.

**Step 2: Create the gold scene file**

Create `scenes/gold/gold.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/gold/gold.gd" id="1"]

[sub_resource type="CircleShape2D" id="SubResource_1"]
radius = 20.0

[node name="Gold" type="Area2D"]
script = ExtResource("1")

[node name="ColorRect" type="ColorRect" parent="."]
offset_left = -8.0
offset_top = -8.0
offset_right = 8.0
offset_bottom = 8.0
color = Color(1, 0.84, 0, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SubResource_1")
```

Notes:
- 16x16 yellow ColorRect (gold color #FFD700 = `Color(1, 0.84, 0, 1)`).
- CircleShape2D radius=20 for comfortable pickup range.
- Default collision layer 1 / mask 1 so `body_entered` fires for the player.

**Step 3: Filter gold out of player's PickupZone**

In `scenes/player/player.gd`, modify `_on_pickup_zone_area_entered` (line 75-79):

Change:
```gdscript
func _on_pickup_zone_area_entered(area: Area2D):
	if "zone_type" in area:
		current_zone = area.zone_type
	elif area != held_item:
		_items_in_range.append(area)
```

To:
```gdscript
func _on_pickup_zone_area_entered(area: Area2D):
	if "zone_type" in area:
		current_zone = area.zone_type
	elif area != held_item and area.has_method("pick_up"):
		_items_in_range.append(area)
```

The only change is adding `and area.has_method("pick_up")`. Items have `pick_up()`, gold doesn't, so gold is ignored.

**Step 4: Run validation**

Run: `just check`
Expected: No parse errors.

Run: `just test`
Expected: All tests PASS (existing player/item tests unaffected since items have `pick_up()`).

**Step 5: Commit**

```bash
git add scenes/gold/gold.gd scenes/gold/gold.tscn scenes/player/player.gd
git commit -m "feat: add gold pickup scene with auto-collect on proximity"
```

---

### Task 3: Rename test_spawner to monster_spawner

**Files:**
- Rename: `scenes/game/test_spawner.gd` → `scenes/game/monster_spawner.gd`
- Modify: `scenes/game/main.tscn:7,43` (update script reference and node name)

**Step 1: Rename the script file**

```bash
git mv scenes/game/test_spawner.gd scenes/game/monster_spawner.gd
```

**Step 2: Update main.tscn references**

In `scenes/game/main.tscn`, change line 7:

```
[ext_resource type="Script" path="res://scenes/game/test_spawner.gd" id="6"]
```
→
```
[ext_resource type="Script" path="res://scenes/game/monster_spawner.gd" id="6"]
```

Change line 43:
```
[node name="TestSpawner" type="Node2D" parent="."]
```
→
```
[node name="MonsterSpawner" type="Node2D" parent="."]
```

Change line 46 (SpawnTimer parent path):
```
[node name="SpawnTimer" type="Timer" parent="TestSpawner"]
```
→
```
[node name="SpawnTimer" type="Timer" parent="MonsterSpawner"]
```

**Step 3: Run validation**

Run: `just check`
Expected: No parse errors.

**Step 4: Commit**

```bash
git add scenes/game/monster_spawner.gd scenes/game/main.tscn
git rm --cached scenes/game/test_spawner.gd
git commit -m "refactor: rename test_spawner to monster_spawner"
```

---

### Task 4: Create GoldSpawner

**Files:**
- Create: `scenes/game/gold_spawner.gd`
- Modify: `scenes/game/main.tscn` (add GoldSpawner node)

**Step 1: Write the gold spawner script**

Create `scenes/game/gold_spawner.gd`:

```gdscript
extends Node2D

## Gold Spawner — spawns gold pickups during day, cleans up sea-zone gold at night.
## Designers: adjust gold_per_day to control daytime gold spawning.

@export var spawn_area_path: NodePath
@export var sea_zone_path: NodePath
@export var gold_per_day: int = 5

var _gold_scene: PackedScene = preload("res://scenes/gold/gold.tscn")
var _spawn_area: Area2D
var _sea_zone: Area2D

func _ready() -> void:
	if spawn_area_path:
		_spawn_area = get_node(spawn_area_path) as Area2D
	if sea_zone_path:
		_sea_zone = get_node(sea_zone_path) as Area2D
	GameManager.day_started.connect(_on_day_started)
	GameManager.night_started.connect(_on_night_started)

func _on_day_started() -> void:
	_spawn_gold()

func _on_night_started() -> void:
	_cleanup_sea_gold()

func _spawn_gold() -> void:
	if _spawn_area == null:
		push_error("GoldSpawner: spawn_area is not assigned.")
		return
	for _i in gold_per_day:
		var gold: Area2D = _gold_scene.instantiate()
		gold.global_position = _random_point_in_spawn_area()
		get_parent().add_child(gold)

func _random_point_in_spawn_area() -> Vector2:
	var shape: CollisionShape2D = _spawn_area.get_child(0) as CollisionShape2D
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	var extents: Vector2 = rect.size / 2.0
	var local_pos: Vector2 = Vector2(
		randf_range(-extents.x, extents.x),
		randf_range(-extents.y, extents.y)
	)
	return _spawn_area.global_position + shape.position + local_pos

func _cleanup_sea_gold() -> void:
	if _sea_zone == null:
		push_error("GoldSpawner: sea_zone is not assigned.")
		return
	var zone_pos: Vector2 = _sea_zone.global_position
	var zone_half_width: float = _sea_zone.zone_width / 2.0
	var zone_left: float = zone_pos.x - zone_half_width
	var zone_right: float = zone_pos.x + zone_half_width
	for gold in get_tree().get_nodes_in_group("gold"):
		if is_instance_valid(gold) and gold.global_position.x >= zone_left and gold.global_position.x <= zone_right:
			gold.queue_free()
```

Notes:
- Reuses same `_random_point_in_spawn_area()` pattern from ItemSpawner.
- Cleanup uses position check against SeaZone's bounds (read from `zone_width` export). This is simpler and more reliable than physics overlap checks.
- All gold is in the "gold" group (set in `gold.gd:_ready`), so `get_tree().get_nodes_in_group("gold")` finds ALL gold regardless of which spawner created it.

**Step 2: Add GoldSpawner node to main.tscn**

In `scenes/game/main.tscn`, add an ext_resource for the script and a new node. Add after the ItemSpawner node:

Add ext_resource (after existing ones):
```
[ext_resource type="Script" path="res://scenes/game/gold_spawner.gd" id="11"]
```

Add node (after ItemSpawner node block):
```
[node name="GoldSpawner" type="Node2D" parent="."]
script = ExtResource("11")
spawn_area_path = NodePath("../ItemSpawnArea")
sea_zone_path = NodePath("../Zones/SeaZone")
```

**Step 3: Run validation**

Run: `just check`
Expected: No parse errors.

**Step 4: Commit**

```bash
git add scenes/game/gold_spawner.gd scenes/game/main.tscn
git commit -m "feat: add GoldSpawner for daytime gold with zone-based cleanup"
```

---

### Task 5: Monster death gold drops

**Files:**
- Modify: `scenes/game/monster_spawner.gd` (add gold drop on monster death)

**Step 1: Add gold drop logic to MonsterSpawner**

Modify `scenes/game/monster_spawner.gd` to add gold spawning on monster death:

```gdscript
extends Node2D

@export var spawn_interval: float = 3.0
@export var spawn_x: float = 400.0
@export var spawn_y_min: float = -300.0
@export var spawn_y_max: float = 300.0
@export var gold_per_kill: int = 3

var _monster_scene: PackedScene = preload("res://scenes/monster/monster.tscn")
var _gold_scene: PackedScene = preload("res://scenes/gold/gold.tscn")

func _ready() -> void:
	$SpawnTimer.wait_time = spawn_interval
	$SpawnTimer.timeout.connect(_on_spawn_timer_timeout)
	GameManager.night_started.connect(_on_night_started)
	GameManager.day_started.connect(_on_day_started)

func _on_night_started() -> void:
	$SpawnTimer.start()

func _on_day_started() -> void:
	$SpawnTimer.stop()
	_cleanup_monsters()

func _cleanup_monsters() -> void:
	var monsters_node: Node = get_parent().get_node("Monsters")
	for monster in monsters_node.get_children():
		monster.queue_free()

func _on_spawn_timer_timeout() -> void:
	var monster: Area2D = _monster_scene.instantiate()
	var spawn_y: float = randf_range(spawn_y_min, spawn_y_max)
	monster.global_position = Vector2(spawn_x, spawn_y)
	monster.died.connect(_on_monster_died.bind(monster))
	get_parent().get_node("Monsters").add_child(monster)

func _on_monster_died(monster: Area2D) -> void:
	var death_pos: Vector2 = monster.global_position
	for _i in gold_per_kill:
		var gold: Area2D = _gold_scene.instantiate()
		var offset: Vector2 = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		gold.global_position = death_pos + offset
		get_parent().add_child(gold)
```

Changes from original test_spawner.gd:
- Added `@export var gold_per_kill: int = 3`
- Added `var _gold_scene: PackedScene = preload("res://scenes/gold/gold.tscn")`
- Connected `monster.died` signal with `bind(monster)` to capture the monster reference
- Added `_on_monster_died()` that spawns gold with small random offsets around death position

Note: `died` signal fires before `queue_free()` in monster.gd (line 20-21), so `monster.global_position` is still valid when the signal handler runs.

**Step 2: Run validation**

Run: `just check`
Expected: No parse errors.

**Step 3: Commit**

```bash
git add scenes/game/monster_spawner.gd
git commit -m "feat: monsters drop gold on death"
```

---

### Task 6: Gold UI label

**Files:**
- Create: `scenes/game/gold_label.gd`
- Modify: `scenes/game/main.tscn` (add GoldLabel node to UI)

**Step 1: Write the gold label script**

Create `scenes/game/gold_label.gd`:

```gdscript
extends Label

func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	text = "Gold: 0"

func _on_gold_changed(new_amount: int) -> void:
	text = "Gold: " + str(new_amount)
```

**Step 2: Add GoldLabel node to main.tscn**

In `scenes/game/main.tscn`, add ext_resource and node:

Add ext_resource:
```
[ext_resource type="Script" path="res://scenes/game/gold_label.gd" id="12"]
```

Add node inside UI CanvasLayer (after PhaseLabel):
```
[node name="GoldLabel" type="Label" parent="UI"]
offset_left = 10.0
offset_top = 40.0
offset_right = 150.0
offset_bottom = 70.0
script = ExtResource("12")
```

This places the GoldLabel below the PhaseLabel (which ends at y=40).

**Step 3: Run validation**

Run: `just check`
Expected: No parse errors.

**Step 4: Commit**

```bash
git add scenes/game/gold_label.gd scenes/game/main.tscn
git commit -m "feat: add gold UI label showing current gold count"
```

---

### Task 7: Final validation and manual testing

**Step 1: Run all tests**

Run: `just test`
Expected: All tests PASS.

**Step 2: Run project validation**

Run: `just check`
Expected: No errors.

**Step 3: Manual verification checklist**

Run the game and verify:
- [ ] Gold pickups appear as yellow squares in the sea zone when day starts
- [ ] Walking the player near gold auto-collects it (no interact key)
- [ ] Gold count updates in UI label
- [ ] Existing item pickup still works (not broken by `has_method` filter)
- [ ] When night starts, gold in the sea zone disappears
- [ ] Monsters spawn at night and can be killed
- [ ] Killed monsters drop gold at their death position
- [ ] Monster-drop gold on the beach persists through night
- [ ] Monster-drop gold in the sea zone is cleaned up at night
- [ ] Gold count persists across day/night cycles
- [ ] PhaseLabel and GoldLabel both visible in UI

**Step 4: Commit any fixes, then final commit**

```bash
git add -A
git commit -m "feat: complete gold system (SCA-25)"
```
