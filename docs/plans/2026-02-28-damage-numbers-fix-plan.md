# Damage Numbers Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix damage numbers disappearing on killing blows by moving label spawning out of the monster into a dedicated DamageNumbers scene node.

**Architecture:** Monster emits a `damage_taken` signal instead of spawning labels directly. A `DamageNumbers` Node2D in the game scene receives the signal (wired by the spawner) and spawns `BasicFloatLabel` instances as its own children, so they survive monster death.

**Tech Stack:** GDScript, Godot 4 signals, GUT test framework

---

### Task 1: Add `damage_taken` signal to monster and update tests

**Files:**
- Modify: `scenes/monster/monster.gd`
- Modify: `core/tests/test_monster.gd`

**Step 1: Write the failing test**

Add to `core/tests/test_monster.gd`:

```gdscript
func test_take_damage_emits_damage_taken():
	watch_signals(monster)
	monster.global_position = Vector2(100, 200)
	monster.take_damage(10.0)
	assert_signal_emitted(monster, "damage_taken")
```

**Step 2: Run test to verify it fails**

Run: `just check` then run GUT tests
Expected: FAIL — signal `damage_taken` does not exist

**Step 3: Update monster.gd**

Replace the entire `scenes/monster/monster.gd` with:

```gdscript
extends Area2D

signal died
signal damage_taken(amount: float, pos: Vector2)

@export var hp: float = 30.0
@export var speed: float = 50.0
@export var despawn_x: float = -500.0

func _physics_process(delta: float) -> void:
	global_position.x -= speed * delta
	if global_position.x < despawn_x:
		queue_free()

func take_damage(amount: float) -> void:
	hp -= amount
	damage_taken.emit(amount, global_position)
	if hp <= 0:
		died.emit()
		queue_free()
```

Key changes:
- Added `signal damage_taken(amount: float, pos: Vector2)`
- Removed `_basic_float_label_scene` preload
- Removed `_show_damage_number()` method
- `take_damage()` now emits `damage_taken` signal instead of spawning label

**Step 4: Run tests to verify they pass**

Run: `just check` then run GUT tests
Expected: All tests PASS (including existing tests and the new one)

**Step 5: Commit**

```bash
git add scenes/monster/monster.gd core/tests/test_monster.gd
git commit -m "refactor: monster emits damage_taken signal instead of spawning labels"
```

---

### Task 2: Create DamageNumbers node script

**Files:**
- Create: `scenes/game/damage_numbers.gd`

**Step 1: Create the script**

Create `scenes/game/damage_numbers.gd`:

```gdscript
extends Node2D

var _basic_float_label_scene: PackedScene = preload("res://scenes/components/NumberLabel/basic_float_label.tscn")

func show_damage(amount: float, pos: Vector2) -> void:
	var label: Label = _basic_float_label_scene.instantiate()
	label.text = str(int(amount))
	label.global_position = pos
	add_child(label)
```

**Step 2: Run validation**

Run: `just check`
Expected: No parse errors

**Step 3: Commit**

```bash
git add scenes/game/damage_numbers.gd
git commit -m "feat: add DamageNumbers node script for floating damage labels"
```

---

### Task 3: Wire DamageNumbers into the game scene

**Files:**
- Modify: `scenes/game/main.tscn` (add DamageNumbers node)
- Modify: `scenes/game/monster_spawner.gd` (connect signal)

**Step 1: Add DamageNumbers node to main.tscn**

Add a `DamageNumbers` Node2D node as a child of `Main` in `scenes/game/main.tscn`. It should use the `scenes/game/damage_numbers.gd` script. Place it after the `Monsters` node in the scene tree.

**Step 2: Update monster_spawner.gd to wire the signal**

Replace `scenes/game/monster_spawner.gd` with:

```gdscript
extends Node2D

@export var spawn_interval: float = 3.0
@export var spawn_x: float = 400.0
@export var spawn_y_min: float = -300.0
@export var spawn_y_max: float = 300.0
@export var gold_per_kill: int = 3

var _monster_scene: PackedScene = preload("res://scenes/monster/monster.tscn")
var _gold_scene: PackedScene = preload("res://scenes/gold/gold.tscn")

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

func _on_monster_died(monster: Area2D) -> void:
	var death_pos: Vector2 = monster.global_position
	for _i in gold_per_kill:
		var gold: Area2D = _gold_scene.instantiate()
		var offset: Vector2 = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		gold.global_position = death_pos + offset
		get_parent().add_child(gold)
```

Key changes:
- Added `@onready var _damage_numbers` to get reference to sibling DamageNumbers node
- In `_on_spawn_timer_timeout()`: added `monster.damage_taken.connect(_damage_numbers.show_damage)`

**Step 3: Run validation**

Run: `just check`
Expected: No parse errors

**Step 4: Commit**

```bash
git add scenes/game/main.tscn scenes/game/monster_spawner.gd
git commit -m "feat: wire DamageNumbers node into game scene via monster spawner"
```

---

### Task 4: Manual verification and cleanup

**Step 1: Run full validation**

Run: `just check`
Expected: All clean, no errors

**Step 2: Manual test checklist**

Play the game and verify:
- [ ] Turret projectile hitting a monster shows a floating damage number
- [ ] Turret killing blow shows a damage number that persists and animates
- [ ] Hammer bonk shows damage numbers for all hit monsters
- [ ] Hammer killing blow shows damage numbers that persist
- [ ] AOE item shows damage numbers on all hit monsters
- [ ] Damage numbers float upward and fade out over 0.8 seconds
- [ ] No visual regressions (numbers still gold/yellow with outline)

**Step 3: Final commit if any adjustments needed**
