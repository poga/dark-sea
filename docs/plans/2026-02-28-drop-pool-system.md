# Drop Pool System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace hardcoded gold drops with a data-driven drop pool system supporting multiple resource types and item drops.

**Architecture:** Centralized `DropManager` singleton loads JSON drop tables at startup, preloads all referenced scenes, and handles all drop spawning when monsters die. `GameManager` gets a generic resource dictionary replacing the gold-only system. The gold pickup scene is generalized to `ResourcePickup` supporting any resource type with configurable icon.

**Tech Stack:** Godot 4.6, GDScript, GUT test framework, JSON data files

---

### Task 1: Add generic resource system to GameManager

**Files:**
- Modify: `core/game_manager.gd`
- Modify: `core/tests/test_game_manager.gd`

**Step 1: Write the failing tests**

Add these tests to `core/tests/test_game_manager.gd`:

```gdscript
func test_add_resource_stores_value():
	GameManager.add_resource("bones", 5)
	assert_eq(GameManager.get_resource("bones"), 5)

func test_add_resource_accumulates():
	GameManager.add_resource("bones", 2)
	GameManager.add_resource("bones", 3)
	assert_eq(GameManager.get_resource("bones"), 5)

func test_add_resource_emits_resource_changed():
	watch_signals(GameManager)
	GameManager.add_resource("bones", 3)
	assert_signal_emitted_with_parameters(GameManager, "resource_changed", ["bones", 3])

func test_get_resource_returns_zero_for_unknown():
	assert_eq(GameManager.get_resource("unknown_type"), 0)

func test_add_gold_uses_resource_system():
	GameManager.add_gold(5)
	assert_eq(GameManager.get_resource("gold"), 5)

func test_add_gold_still_emits_gold_changed():
	watch_signals(GameManager)
	GameManager.add_gold(3)
	assert_signal_emitted_with_parameters(GameManager, "gold_changed", [3])
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `resource_changed` signal doesn't exist, `add_resource`/`get_resource` methods don't exist

**Step 3: Implement generic resource system**

In `core/game_manager.gd`:

1. Add signal after existing signals:
```gdscript
signal resource_changed(type: String, new_amount: int)
```

2. Add `resources` dictionary next to `gold`:
```gdscript
var resources: Dictionary = {}
```

3. Add methods after `add_gold`:
```gdscript
func add_resource(type: String, amount: int) -> void:
	if not resources.has(type):
		resources[type] = 0
	resources[type] += amount
	resource_changed.emit(type, resources[type])

func get_resource(type: String) -> int:
	return resources.get(type, 0)
```

4. Update `add_gold` to use the resource system:
```gdscript
func add_gold(amount: int) -> void:
	add_resource("gold", amount)
	gold += amount
	gold_changed.emit(gold)
```

Wait — `add_resource` already increments `resources["gold"]`. We need `gold` var for backward compat with existing tests that check `GameManager.gold`. Keep `gold` as a convenience alias that stays in sync:

```gdscript
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	add_resource("gold", amount)
```

Note: `add_resource` will also emit `resource_changed` for "gold", which is fine — GoldLabel can migrate later.

5. Update `before_each` in `core/tests/test_game_manager.gd` to also reset resources:
```gdscript
func before_each() -> void:
	GameManager.gold = 0
	GameManager.resources = {}
```

**Step 4: Run tests to verify they pass**

Run: `just test`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add core/game_manager.gd core/tests/test_game_manager.gd
git commit -m "feat(resources): add generic resource system to GameManager"
```

---

### Task 2: Update Monster to emit typed died signal

**Files:**
- Modify: `scenes/monster/monster.gd`
- Modify: `core/tests/test_monster.gd`

**Step 1: Write the failing test**

Add to `core/tests/test_monster.gd`:

```gdscript
func test_monster_type_defaults_to_default():
	assert_eq(monster.monster_type, "default")

func test_died_signal_includes_type_and_position():
	watch_signals(monster)
	monster.global_position = Vector2(100, 200)
	monster.take_damage(30.0)
	assert_signal_emitted_with_parameters(monster, "died", ["default", Vector2(100, 200)])
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `monster_type` property doesn't exist, `died` signal has no parameters

**Step 3: Update monster script**

In `scenes/monster/monster.gd`:

1. Change the signal declaration:
```gdscript
signal died(monster_type: String, position: Vector2)
```

2. Add the export:
```gdscript
@export var monster_type: String = "default"
```

3. Update `take_damage` to emit with parameters:
```gdscript
func take_damage(amount: float) -> void:
	hp -= amount
	damage_taken.emit(amount, global_position)
	if hp <= 0:
		died.emit(monster_type, global_position)
		queue_free()
```

**Step 4: Update MonsterSpawner for new signal signature**

The `died` signal now has 2 parameters. `MonsterSpawner._on_monster_died` currently takes `monster: Area2D` via `.bind(monster)`. Update `scenes/game/monster_spawner.gd`:

1. Change the connection in `_on_spawn_timer_timeout`:
```gdscript
monster.died.connect(_on_monster_died.bind(monster))
```

2. Update the handler signature — it now receives `monster_type, position` from signal + `monster` from bind:
```gdscript
func _on_monster_died(monster_type: String, death_pos: Vector2, monster: Area2D) -> void:
```

Keep the existing gold spawning logic for now (Task 5 will remove it). Just update to use `death_pos` from the signal instead of `monster.global_position`:

```gdscript
func _on_monster_died(monster_type: String, death_pos: Vector2, monster: Area2D) -> void:
	for _i in gold_per_kill:
		var gold: Area2D = _gold_scene.instantiate()
		gold.global_position = death_pos
		var angle: float = randf() * TAU
		var speed: float = randf_range(gold_burst_speed_min, gold_burst_speed_max)
		var burst_vel: Vector2 = Vector2.from_angle(angle) * speed
		get_parent().add_child(gold)
		gold.start_spawning(burst_vel)
```

**Step 5: Run tests to verify they pass**

Run: `just test`
Expected: ALL PASS

**Step 6: Commit**

```bash
git add scenes/monster/monster.gd core/tests/test_monster.gd scenes/game/monster_spawner.gd
git commit -m "feat(monster): add monster_type export and typed died signal"
```

---

### Task 3: Create ResourcePickup scene (generalize from gold)

**Files:**
- Create: `scenes/pickup/resource_pickup.gd`
- Create: `scenes/pickup/resource_pickup.tscn`
- Create: `core/tests/test_resource_pickup.gd`

**Step 1: Write the failing tests**

Create `core/tests/test_resource_pickup.gd`:

```gdscript
extends GutTest

var _pickup_scene: PackedScene = preload("res://scenes/pickup/resource_pickup.tscn")

func before_each() -> void:
	GameManager.resources = {}

func test_pickup_starts_in_idle_state():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	assert_eq(pickup.current_state, pickup.State.IDLE)

func test_start_spawning_sets_state():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(100, 0))
	assert_eq(pickup.current_state, pickup.State.SPAWNING)

func test_spawning_applies_friction():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(200, 0))
	var start_pos: Vector2 = pickup.global_position
	pickup._process_spawning(0.016)
	assert_ne(pickup.global_position, start_pos, "Pickup should have moved")

func test_spawning_transitions_to_idle_when_slow():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(1, 0))
	pickup._process_spawning(0.016)
	assert_eq(pickup.current_state, pickup.State.IDLE)

func test_resource_type_defaults_to_gold():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	assert_eq(pickup.resource_type, "gold")

func test_collecting_adds_resource_to_game_manager():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.resource_type = "bones"
	pickup.value = 3
	pickup.global_position = Vector2(5, 0)
	var target: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(target)
	target.global_position = Vector2.ZERO
	pickup._start_collecting(target)
	pickup._process_collecting(0.5)
	# Pickup should have reached target and added resource
	assert_eq(GameManager.get_resource("bones"), 3)

func test_body_entered_during_idle_starts_rising():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	assert_eq(pickup.current_state, pickup.State.IDLE)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	pickup._on_body_entered(dummy)
	assert_eq(pickup.current_state, pickup.State.RISING)

func test_collecting_moves_toward_target():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.global_position = Vector2(100, 0)
	var target: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(target)
	target.global_position = Vector2.ZERO
	pickup._start_collecting(target)
	var start_dist: float = pickup.global_position.distance_to(target.global_position)
	pickup._process_collecting(0.1)
	var end_dist: float = pickup.global_position.distance_to(target.global_position)
	assert_lt(end_dist, start_dist, "Pickup should move closer to target")
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — scene file doesn't exist

**Step 3: Create the ResourcePickup script**

Create `scenes/pickup/resource_pickup.gd` — this is a generalized version of `scenes/gold/gold.gd`:

```gdscript
extends Area2D

@export var resource_type: String = "gold"
@export var value: int = 1
@export var icon: Texture2D
@export var friction: float = 0.85
@export var stop_threshold: float = 5.0
@export var magnet_acceleration: float = 3000.0
@export var magnet_max_speed: float = 1200.0
@export var pulse_min_alpha: float = 0.7
@export var rise_height: float = 20.0
@export var rise_duration: float = 0.2
@export var rise_pause: float = 0.15

enum State { SPAWNING, IDLE, RISING, COLLECTING }

var current_state: State = State.IDLE
var _velocity: Vector2 = Vector2.ZERO
var _target_body: Node2D = null
var _pulse_tween: Tween = null
var _rise_tween: Tween = null

func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	if icon and has_node("Sprite2D"):
		$Sprite2D.texture = icon

func start_spawning(vel: Vector2) -> void:
	_velocity = vel
	current_state = State.SPAWNING

func _physics_process(delta: float) -> void:
	match current_state:
		State.SPAWNING:
			_process_spawning(delta)
		State.RISING:
			pass
		State.COLLECTING:
			_process_collecting(delta)

func _process_spawning(delta: float) -> void:
	_velocity *= pow(friction, delta * 60.0)
	global_position += _velocity * delta
	if _velocity.length() < stop_threshold:
		_enter_idle()

func _enter_idle() -> void:
	current_state = State.IDLE
	_velocity = Vector2.ZERO
	_start_pulse()
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			_enter_rising(body)
			return

func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate:a", pulse_min_alpha, 0.6)
	_pulse_tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _on_body_entered(body: Node2D) -> void:
	if current_state == State.IDLE and body is CharacterBody2D:
		_enter_rising(body)

func _enter_rising(body: CharacterBody2D) -> void:
	current_state = State.RISING
	_target_body = body
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	modulate.a = 1.0
	_rise_tween = create_tween()
	_rise_tween.tween_property(self, "global_position:y", global_position.y - rise_height, rise_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_rise_tween.tween_interval(rise_pause)
	_rise_tween.tween_callback(_on_rise_complete)

func _on_rise_complete() -> void:
	if not is_instance_valid(_target_body):
		queue_free()
		return
	_start_collecting(_target_body)

func _start_collecting(body: CharacterBody2D) -> void:
	current_state = State.COLLECTING
	_target_body = body
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	modulate.a = 1.0

func _process_collecting(delta: float) -> void:
	if not is_instance_valid(_target_body):
		queue_free()
		return
	var desired: Vector2 = (_target_body.global_position - global_position).normalized() * magnet_max_speed
	_velocity = _velocity.move_toward(desired, magnet_acceleration * delta)
	global_position += _velocity * delta
	var dist: float = global_position.distance_to(_target_body.global_position)
	if dist < 10.0:
		GameManager.add_resource(resource_type, value)
		queue_free()
```

**Step 4: Create the ResourcePickup scene file**

Create `scenes/pickup/resource_pickup.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/pickup/resource_pickup.gd" id="1"]

[sub_resource type="CircleShape2D" id="SubResource_1"]
radius = 20.0

[node name="ResourcePickup" type="Area2D"]
script = ExtResource("1")
rise_height = 30.0
rise_duration = 0.1
rise_pause = 0.2

[node name="ColorRect" type="ColorRect" parent="."]
offset_left = -8.0
offset_top = -8.0
offset_right = 8.0
offset_bottom = 8.0
color = Color(1, 0.84, 0, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SubResource_1")
```

**Step 5: Run tests to verify they pass**

Run: `just test`
Expected: ALL PASS

**Step 6: Commit**

```bash
git add scenes/pickup/resource_pickup.gd scenes/pickup/resource_pickup.tscn core/tests/test_resource_pickup.gd
git commit -m "feat(pickup): create generalized ResourcePickup scene from gold pickup"
```

---

### Task 4: Create drop_tables.json data file

**Files:**
- Create: `data/drop_tables.json`

**Step 1: Create the data directory and JSON file**

Create `data/drop_tables.json`:

```json
{
  "default": {
    "drops": [
      { "type": "gold", "chance": 1.0, "min": 1, "max": 3 }
    ]
  }
}
```

Start with just "default" type matching the monster's default `monster_type`. More types will be added by designers later.

**Step 2: Commit**

```bash
git add data/drop_tables.json
git commit -m "feat(drops): add initial drop_tables.json data file"
```

---

### Task 5: Create DropManager singleton

**Files:**
- Create: `core/drop_manager.gd`
- Create: `core/tests/test_drop_manager.gd`
- Modify: `project.godot`

**Step 1: Write the failing tests**

Create `core/tests/test_drop_manager.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	GameManager.resources = {}

func test_load_drop_tables_parses_json():
	DropManager.load_drop_tables()
	assert_true(DropManager.drop_tables.has("default"), "Should have 'default' monster type")

func test_default_monster_has_drops():
	DropManager.load_drop_tables()
	var drops: Array = DropManager.drop_tables["default"]["drops"]
	assert_gt(drops.size(), 0, "Default monster should have at least one drop entry")

func test_roll_drops_returns_results():
	DropManager.load_drop_tables()
	# Roll with chance 1.0 gold should always produce results
	var results: Array = DropManager.roll_drops_for("default")
	assert_gt(results.size(), 0, "Should have at least one drop result")

func test_roll_drops_respects_chance_zero():
	# Manually set a drop table with 0% chance
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "gold", "chance": 0.0, "min": 1, "max": 1 }
			]
		}
	}
	var results: Array = DropManager.roll_drops_for("test_monster")
	assert_eq(results.size(), 0, "0% chance should never drop")

func test_roll_drops_respects_chance_one():
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "gold", "chance": 1.0, "min": 2, "max": 2 }
			]
		}
	}
	var results: Array = DropManager.roll_drops_for("test_monster")
	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "gold")
	assert_eq(results[0]["amount"], 2)

func test_roll_drops_amount_in_range():
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "gold", "chance": 1.0, "min": 1, "max": 5 }
			]
		}
	}
	# Roll many times to check range
	for _i in 20:
		var results: Array = DropManager.roll_drops_for("test_monster")
		assert_gte(results[0]["amount"], 1)
		assert_lte(results[0]["amount"], 5)

func test_roll_drops_unknown_type_returns_empty():
	DropManager.load_drop_tables()
	var results: Array = DropManager.roll_drops_for("nonexistent_monster")
	assert_eq(results.size(), 0)

func test_roll_drops_item_entry():
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "item", "chance": 1.0, "scene": "res://scenes/item/turret_item.tscn" }
			]
		}
	}
	DropManager._preload_scenes()
	var results: Array = DropManager.roll_drops_for("test_monster")
	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "item")
	assert_true(results[0].has("scene"), "Item drops should include scene path")

func test_multiple_independent_drops():
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "gold", "chance": 1.0, "min": 1, "max": 1 },
				{ "type": "bones", "chance": 1.0, "min": 1, "max": 1 }
			]
		}
	}
	var results: Array = DropManager.roll_drops_for("test_monster")
	assert_eq(results.size(), 2, "Both entries with 100% chance should drop")
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — DropManager singleton doesn't exist

**Step 3: Create DropManager singleton**

Create `core/drop_manager.gd`:

```gdscript
extends Node

const DROP_TABLE_PATH: String = "res://data/drop_tables.json"

var drop_tables: Dictionary = {}
var _preloaded_item_scenes: Dictionary = {}
var _pickup_scene: PackedScene = preload("res://scenes/pickup/resource_pickup.tscn")

func _ready() -> void:
	load_drop_tables()

func load_drop_tables() -> void:
	var file := FileAccess.open(DROP_TABLE_PATH, FileAccess.READ)
	if file == null:
		push_error("DropManager: Could not open %s" % DROP_TABLE_PATH)
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		push_error("DropManager: JSON parse error in %s: %s" % [DROP_TABLE_PATH, json.get_error_message()])
		return
	drop_tables = json.data
	_preload_scenes()

func _preload_scenes() -> void:
	_preloaded_item_scenes.clear()
	for monster_type: String in drop_tables:
		var drops: Array = drop_tables[monster_type]["drops"]
		for entry: Dictionary in drops:
			if entry["type"] == "item" and entry.has("scene"):
				var scene_path: String = entry["scene"]
				if not _preloaded_item_scenes.has(scene_path):
					_preloaded_item_scenes[scene_path] = load(scene_path)

func roll_drops_for(monster_type: String) -> Array:
	if not drop_tables.has(monster_type):
		return []
	var results: Array = []
	var drops: Array = drop_tables[monster_type]["drops"]
	for entry: Dictionary in drops:
		if randf() >= entry["chance"]:
			continue
		if entry["type"] == "item":
			results.append({
				"type": "item",
				"scene": entry["scene"],
			})
		else:
			var amount: int = randi_range(int(entry["min"]), int(entry["max"]))
			results.append({
				"type": entry["type"],
				"amount": amount,
			})
	return results

func spawn_drops(monster_type: String, position: Vector2, parent: Node) -> void:
	var results: Array = roll_drops_for(monster_type)
	for result: Dictionary in results:
		if result["type"] == "item":
			_spawn_item_drop(result, position, parent)
		else:
			_spawn_resource_drop(result, position, parent)

func _spawn_resource_drop(result: Dictionary, position: Vector2, parent: Node) -> void:
	var pickup: Area2D = _pickup_scene.instantiate()
	pickup.resource_type = result["type"]
	pickup.value = result["amount"]
	pickup.global_position = position
	var angle: float = randf() * TAU
	var speed: float = randf_range(150.0, 300.0)
	var burst_vel: Vector2 = Vector2.from_angle(angle) * speed
	parent.add_child(pickup)
	pickup.start_spawning(burst_vel)

func _spawn_item_drop(result: Dictionary, position: Vector2, parent: Node) -> void:
	var scene_path: String = result["scene"]
	var scene: PackedScene = _preloaded_item_scenes.get(scene_path)
	if scene == null:
		push_error("DropManager: No preloaded scene for %s" % scene_path)
		return
	var item: Area2D = scene.instantiate()
	item.global_position = position
	parent.add_child(item)
```

**Step 4: Register DropManager autoload in project.godot**

In `project.godot`, under `[autoload]`, add:

```ini
DropManager="*res://core/drop_manager.gd"
```

So it becomes:
```ini
[autoload]

GameManager="*res://core/game_manager.gd"
DropManager="*res://core/drop_manager.gd"
```

**Step 5: Run tests to verify they pass**

Run: `just test`
Expected: ALL PASS

**Step 6: Commit**

```bash
git add core/drop_manager.gd core/tests/test_drop_manager.gd project.godot
git commit -m "feat(drops): add DropManager singleton with JSON-driven drop tables"
```

---

### Task 6: Wire MonsterSpawner to DropManager

**Files:**
- Modify: `scenes/game/monster_spawner.gd`

**Step 1: Update MonsterSpawner to delegate drops to DropManager**

In `scenes/game/monster_spawner.gd`:

1. Remove gold-related exports and preloads:
```gdscript
# REMOVE these lines:
@export var gold_per_kill: int = 3
@export var gold_burst_speed_min: float = 150.0
@export var gold_burst_speed_max: float = 300.0
var _gold_scene: PackedScene = preload("res://scenes/gold/gold.tscn")
```

2. Replace `_on_monster_died` with:
```gdscript
func _on_monster_died(monster_type: String, death_pos: Vector2, _monster: Area2D) -> void:
	DropManager.spawn_drops(monster_type, death_pos, get_parent())
```

Full updated file:
```gdscript
extends Node2D

@export var spawn_interval: float = 3.0
@export var spawn_x: float = 400.0
@export var spawn_y_min: float = -300.0
@export var spawn_y_max: float = 300.0

var _monster_scene: PackedScene = preload("res://scenes/monster/monster.tscn")

@onready var _damage_numbers: Node2D = get_parent().get_node("DamageNumbers")

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
	monster.damage_taken.connect(_damage_numbers.show_damage)
	get_parent().get_node("Monsters").add_child(monster)

func _on_monster_died(monster_type: String, death_pos: Vector2, _monster: Area2D) -> void:
	DropManager.spawn_drops(monster_type, death_pos, get_parent())
```

**Step 2: Run tests and validate**

Run: `just check`
Expected: ALL PASS — no parse errors, tests pass

**Step 3: Commit**

```bash
git add scenes/game/monster_spawner.gd
git commit -m "feat(drops): wire MonsterSpawner to DropManager, remove hardcoded gold"
```

---

### Task 7: Migrate GoldSpawner to use ResourcePickup

**Files:**
- Modify: `scenes/game/gold_spawner.gd`

**Step 1: Update GoldSpawner to use new ResourcePickup scene**

In `scenes/game/gold_spawner.gd`, change the preload:

```gdscript
# OLD:
var _gold_scene: PackedScene = preload("res://scenes/gold/gold.tscn")
# NEW:
var _gold_scene: PackedScene = preload("res://scenes/pickup/resource_pickup.tscn")
```

Also update the group name used in `_cleanup_sea_gold` from `"gold"` to `"pickup"`:

```gdscript
func _cleanup_sea_gold() -> void:
	if _sea_zone == null:
		push_error("GoldSpawner: sea_zone is not assigned.")
		return
	var zone_pos: Vector2 = _sea_zone.global_position
	var zone_half_width: float = _sea_zone.zone_width / 2.0
	var zone_left: float = zone_pos.x - zone_half_width
	var zone_right: float = zone_pos.x + zone_half_width
	for gold in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(gold) and gold.global_position.x >= zone_left and gold.global_position.x <= zone_right:
			gold.queue_free()
```

**Step 2: Run validation**

Run: `just check`
Expected: ALL PASS

**Step 3: Commit**

```bash
git add scenes/game/gold_spawner.gd
git commit -m "refactor(gold-spawner): migrate to ResourcePickup scene"
```

---

### Task 8: Update GoldLabel for resource_changed signal

**Files:**
- Modify: `scenes/game/gold_label.gd`

**Step 1: Update GoldLabel to use resource_changed signal**

In `scenes/game/gold_label.gd`:

```gdscript
extends Node2D

var _previous_gold: int = 0

func _ready() -> void:
	GameManager.resource_changed.connect(_on_resource_changed)

func _on_resource_changed(type: String, new_amount: int) -> void:
	if type != "gold":
		return
	var delta: int = new_amount - _previous_gold
	_previous_gold = new_amount
	$NumberLabel.add(delta)
```

**Step 2: Run validation**

Run: `just check`
Expected: ALL PASS

**Step 3: Commit**

```bash
git add scenes/game/gold_label.gd
git commit -m "refactor(gold-label): use resource_changed signal instead of gold_changed"
```

---

### Task 9: Update gold tests to use ResourcePickup

**Files:**
- Modify: `core/tests/test_gold.gd`

**Step 1: Update test file to reference new scene**

Rename the preload and update group references in `core/tests/test_gold.gd`:

```gdscript
extends GutTest

var _pickup_scene: PackedScene = preload("res://scenes/pickup/resource_pickup.tscn")

func before_each() -> void:
	GameManager.resources = {}

func test_pickup_starts_in_idle_state():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	assert_eq(pickup.current_state, pickup.State.IDLE)

func test_start_spawning_sets_state():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(100, 0))
	assert_eq(pickup.current_state, pickup.State.SPAWNING)

func test_spawning_applies_friction():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(200, 0))
	var start_pos: Vector2 = pickup.global_position
	pickup._process_spawning(0.016)
	assert_ne(pickup.global_position, start_pos, "Pickup should have moved")

func test_spawning_transitions_to_idle_when_slow():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(1, 0))
	pickup._process_spawning(0.016)
	assert_eq(pickup.current_state, pickup.State.IDLE)

func test_idle_pickup_ignores_body_during_spawning():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(200, 0))
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	pickup._on_body_entered(dummy)
	assert_eq(pickup.current_state, pickup.State.SPAWNING, "Should stay in SPAWNING")

func test_body_entered_during_idle_starts_rising():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	assert_eq(pickup.current_state, pickup.State.IDLE)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	pickup._on_body_entered(dummy)
	assert_eq(pickup.current_state, pickup.State.RISING)

func test_collecting_moves_toward_target():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.global_position = Vector2(100, 0)
	var target: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(target)
	target.global_position = Vector2.ZERO
	pickup._start_collecting(target)
	var start_dist: float = pickup.global_position.distance_to(target.global_position)
	pickup._process_collecting(0.1)
	var end_dist: float = pickup.global_position.distance_to(target.global_position)
	assert_lt(end_dist, start_dist, "Pickup should move closer to target")

func test_rising_ignores_additional_body_entered():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	var dummy1: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy1)
	pickup._on_body_entered(dummy1)
	assert_eq(pickup.current_state, pickup.State.RISING)
	var dummy2: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy2)
	pickup._on_body_entered(dummy2)
	assert_eq(pickup.current_state, pickup.State.RISING, "Should stay in RISING")

func test_rise_complete_transitions_to_collecting():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	pickup._on_body_entered(dummy)
	assert_eq(pickup.current_state, pickup.State.RISING)
	pickup._on_rise_complete()
	assert_eq(pickup.current_state, pickup.State.COLLECTING)
```

**Step 2: Run tests to verify they pass**

Run: `just test`
Expected: ALL PASS

**Step 3: Commit**

```bash
git add core/tests/test_gold.gd
git commit -m "refactor(tests): migrate gold tests to use ResourcePickup scene"
```

---

### Task 10: Remove old gold scene and clean up references

**Files:**
- Remove: `scenes/gold/gold.gd`
- Remove: `scenes/gold/gold.tscn`
- Modify: `scenes/game/main.tscn` (if any direct references)

**Step 1: Check for remaining references to old gold scene**

Search the codebase for `scenes/gold/` references. At this point:
- `monster_spawner.gd` — already updated (Task 6)
- `gold_spawner.gd` — already updated (Task 7)
- `test_gold.gd` — already updated (Task 9)
- `main.tscn` — no direct gold scene reference (gold is spawned dynamically)

**Step 2: Delete old files**

```bash
rm scenes/gold/gold.gd scenes/gold/gold.tscn
rmdir scenes/gold/
```

**Step 3: Run full validation**

Run: `just check`
Expected: ALL PASS — no broken references

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor(cleanup): remove old gold scene, replaced by ResourcePickup"
```

---

### Task 11: Final integration validation

**Step 1: Run full test suite**

Run: `just check`
Expected: ALL PASS

**Step 2: Verify file structure**

Confirm these exist:
- `core/drop_manager.gd` — singleton
- `core/game_manager.gd` — has `resources`, `add_resource`, `get_resource`, `resource_changed`
- `data/drop_tables.json` — drop table data
- `scenes/pickup/resource_pickup.gd` — generalized pickup
- `scenes/pickup/resource_pickup.tscn` — pickup scene
- `core/tests/test_drop_manager.gd` — drop manager tests
- `core/tests/test_resource_pickup.gd` — pickup tests

Confirm these are gone:
- `scenes/gold/gold.gd`
- `scenes/gold/gold.tscn`

**Step 3: Manual verification checklist**

These should be verified by playing the game:
- Killing a monster drops gold pickups (uses ResourcePickup now)
- Gold pickups still burst, pulse, rise, and collect to player
- Gold counter still updates in UI
- Day-phase gold spawner still works
- Editing `data/drop_tables.json` changes what drops from monsters
