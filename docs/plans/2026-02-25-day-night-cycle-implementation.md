# Day/Night Cycle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a day/night cycle where items spawn during day and monsters spawn during night, driven by GameManager signals.

**Architecture:** GameManager singleton owns phase state and timer, emits signals. ItemSpawner and monster spawner scenes react to signals. Main scene orchestrates startup.

**Tech Stack:** Godot 4.6, GDScript, GUT testing framework

---

### Task 1: GameManager Phase Signals and State

**Files:**
- Modify: `core/game_manager.gd`

**Step 1: Write failing tests for phase cycling**

Add to `core/tests/test_game_manager.gd`:

```gdscript
func test_start_cycle_begins_with_day():
	GameManager.start_cycle()
	assert_eq(GameManager.current_phase, GameManager.Phase.DAY)

func test_start_cycle_emits_day_started():
	watch_signals(GameManager)
	GameManager.start_cycle()
	assert_signal_emitted(GameManager, "day_started")

func test_start_cycle_emits_phase_changed_with_day():
	watch_signals(GameManager)
	GameManager.start_cycle()
	assert_signal_emitted_with_parameters(GameManager, "phase_changed", [GameManager.Phase.DAY])
```

**Step 2: Run tests to verify they fail**

Run: `just check` then run GUT tests in editor.
Expected: FAIL — `start_cycle`, `Phase`, signals not defined.

**Step 3: Implement GameManager phase system**

Replace `core/game_manager.gd` with:

```gdscript
extends Node

signal state_changed(new_state)
signal day_started
signal night_started
signal phase_changed(phase: Phase)

enum Phase { DAY, NIGHT }

var state: int = 0
var current_phase: Phase = Phase.DAY

@export var day_duration: float = 30.0
@export var night_duration: float = 30.0

var _phase_timer: Timer

func _ready() -> void:
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	_phase_timer.timeout.connect(_on_phase_timer_timeout)
	add_child(_phase_timer)

func increment_state():
	state += 1
	state_changed.emit(state)
	return state

func start_cycle() -> void:
	current_phase = Phase.DAY
	day_started.emit()
	phase_changed.emit(current_phase)
	_phase_timer.wait_time = day_duration
	_phase_timer.start()

func get_current_phase() -> Phase:
	return current_phase

func _on_phase_timer_timeout() -> void:
	if current_phase == Phase.DAY:
		current_phase = Phase.NIGHT
		night_started.emit()
	else:
		current_phase = Phase.DAY
		day_started.emit()
	phase_changed.emit(current_phase)
	_phase_timer.wait_time = night_duration if current_phase == Phase.NIGHT else day_duration
	_phase_timer.start()
```

**Step 4: Run tests to verify they pass**

Run: `just check` then run GUT tests.
Expected: All 3 new tests PASS, existing tests still PASS.

**Step 5: Commit**

```bash
git add core/game_manager.gd core/tests/test_game_manager.gd
git commit -m "feat: add day/night phase cycling to GameManager"
```

---

### Task 2: ItemSpawner Script

**Files:**
- Create: `scenes/game/item_spawner.gd`

**Step 1: Create the item spawner script**

Write `scenes/game/item_spawner.gd`:

```gdscript
extends Node2D

## Item Spawner — controls what items spawn each day.
## Designers: edit item_pool and items_per_day to change spawning behavior.
## The spawn_area export is set in the editor to an Area2D with a rectangular CollisionShape2D.

@export var spawn_area: Area2D

# --- Item pool: edit this to change what spawns ---
# Each entry has a scene and a weight (higher = more likely).
var item_pool: Array[Dictionary] = [
	{ "scene": preload("res://scenes/item/item.tscn"), "weight": 3 },
	{ "scene": preload("res://scenes/item/aoe_item.tscn"), "weight": 1 },
]

# --- Spawning rules: edit this to change how many spawn ---
var items_per_day: int = 4

# --- Internal tracking ---
var _spawned_items: Array[Area2D] = []

func _ready() -> void:
	GameManager.day_started.connect(_on_day_started)
	GameManager.night_started.connect(_on_night_started)

func _on_day_started() -> void:
	_spawn_items()

func _on_night_started() -> void:
	_cleanup_uncollected_items()

func _spawn_items() -> void:
	var total_weight: float = 0.0
	for entry in item_pool:
		total_weight += entry["weight"]

	for i in items_per_day:
		var item_scene: PackedScene = _pick_weighted_random(total_weight)
		var item: Area2D = item_scene.instantiate()
		item.global_position = _random_point_in_spawn_area()
		get_parent().add_child(item)
		_spawned_items.append(item)

func _pick_weighted_random(total_weight: float) -> PackedScene:
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for entry in item_pool:
		cumulative += entry["weight"]
		if roll <= cumulative:
			return entry["scene"]
	return item_pool[-1]["scene"]

func _random_point_in_spawn_area() -> Vector2:
	var shape: CollisionShape2D = spawn_area.get_child(0) as CollisionShape2D
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	var extents: Vector2 = rect.size / 2.0
	var local_pos: Vector2 = Vector2(
		randf_range(-extents.x, extents.x),
		randf_range(-extents.y, extents.y)
	)
	return spawn_area.global_position + shape.position + local_pos

func _cleanup_uncollected_items() -> void:
	for item in _spawned_items:
		if is_instance_valid(item) and item.current_state == item.State.PICKUP:
			item.queue_free()
	_spawned_items.clear()
```

**Step 2: Validate script parses**

Run: `just check`
Expected: No parse errors.

**Step 3: Commit**

```bash
git add scenes/game/item_spawner.gd
git commit -m "feat: add script-based item spawner with weighted pool"
```

---

### Task 3: Rework Monster Spawner for Night Phase

**Files:**
- Modify: `scenes/game/test_spawner.gd`

**Step 1: Update test_spawner.gd to react to day/night signals**

Replace `scenes/game/test_spawner.gd` with:

```gdscript
extends Node2D

@export var spawn_interval: float = 3.0
@export var spawn_x: float = 400.0
@export var spawn_y_min: float = -300.0
@export var spawn_y_max: float = 300.0

var _monster_scene: PackedScene = preload("res://scenes/monster/monster.tscn")

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
	get_parent().get_node("Monsters").add_child(monster)
```

**Step 2: Validate script parses**

Run: `just check`
Expected: No parse errors.

**Step 3: Commit**

```bash
git add scenes/game/test_spawner.gd
git commit -m "feat: monster spawner reacts to day/night cycle signals"
```

---

### Task 4: Update Main Scene

**Files:**
- Modify: `scenes/game/main.tscn`
- Create: `scenes/game/main.gd`

**Step 1: Create main scene script**

Write `scenes/game/main.gd`:

```gdscript
extends Node2D

func _ready() -> void:
	GameManager.start_cycle()
```

**Step 2: Update main.tscn**

Edit `scenes/game/main.tscn` to:
- Attach `main.gd` script to the Main node
- Remove hardcoded Item1, Item2, Item3, AoeItem1 nodes (and the Items container)
- Add `ItemSpawnArea` (Area2D) with a `CollisionShape2D` (RectangleShape2D) covering the sea region (~x=100 to x=500, y=-300 to y=300)
- Add `ItemSpawner` (Node2D) with `item_spawner.gd` script, export `spawn_area` pointing to `ItemSpawnArea`
- Add `PhaseLabel` (Label) at top of screen for phase display

The resulting scene tree should be:
```
Main (Node2D + main.gd)
├── Zones
│   ├── TowerZone
│   ├── BeachZone
│   └── SeaZone
├── Player
├── Monsters (Node2D)
├── ItemSpawnArea (Area2D)
│   └── CollisionShape2D (RectangleShape2D, size=400x600)
├── ItemSpawner (Node2D + item_spawner.gd, spawn_area=ItemSpawnArea)
├── TestSpawner (Node2D + test_spawner.gd)
│   └── SpawnTimer (Timer)
└── PhaseLabel (Label)
```

**Step 3: Create PhaseLabel script**

Write `scenes/game/phase_label.gd`:

```gdscript
extends Label

func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: GameManager.Phase) -> void:
	if phase == GameManager.Phase.DAY:
		text = "Day"
	else:
		text = "Night"
```

**Step 4: Validate all scripts parse**

Run: `just check`
Expected: No parse errors.

**Step 5: Commit**

```bash
git add scenes/game/main.gd scenes/game/main.tscn scenes/game/phase_label.gd scenes/game/item_spawner.gd
git commit -m "feat: wire day/night cycle into main scene"
```

---

### Task 5: Manual Verification

**Step 1: Play the game and verify the full cycle**

Run the game in Godot editor. Verify:
- Game starts in Day phase, PhaseLabel shows "Day"
- Items spawn in the sea area
- Player can pick up items and place turrets
- After day_duration seconds, phase switches to Night
- Uncollected items disappear
- Monsters start spawning from the right
- Turrets shoot monsters
- After night_duration seconds, phase switches back to Day
- Monsters are cleaned up, new items spawn
- Cycle repeats

**Step 2: Run all tests**

Run GUT tests in editor.
Expected: All tests pass.

**Step 3: Commit any fixes**

If any adjustments were needed, commit them.

---

### Task 6: Update Linear Issue

**Step 1: Mark SCA-24 as Done**

Update the Linear issue SCA-24 to "Done" state.
