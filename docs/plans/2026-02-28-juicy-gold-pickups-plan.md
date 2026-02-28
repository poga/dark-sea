# Juicy Gold Pickups Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add physics-based burst scatter on monster death and magnetic pull collection to gold pickups.

**Architecture:** Refactor `gold.gd` to use a 3-state machine (SPAWNING → IDLE → COLLECTING). Gold handles its own movement in `_physics_process`. MonsterSpawner sets a velocity vector on each gold instead of random position offsets. Player proximity triggers magnetic acceleration toward the player.

**Tech Stack:** Godot 4, GDScript, GUT test framework

---

### Task 1: Add state machine and SPAWNING state to gold

**Files:**
- Modify: `scenes/gold/gold.gd`

**Step 1: Write the new gold.gd with state machine and SPAWNING logic**

Replace `scenes/gold/gold.gd` entirely:

```gdscript
extends Area2D

@export var value: int = 1
@export var friction: float = 0.85
@export var stop_threshold: float = 5.0
@export var magnet_acceleration: float = 1500.0
@export var magnet_max_speed: float = 600.0
@export var pulse_min_alpha: float = 0.7

enum State { SPAWNING, IDLE, COLLECTING }

var current_state: State = State.IDLE
var spawn_velocity: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _target_body: Node2D = null
var _pulse_tween: Tween = null

func _ready() -> void:
	add_to_group("gold")
	body_entered.connect(_on_body_entered)

func start_spawning(vel: Vector2) -> void:
	spawn_velocity = vel
	_velocity = vel
	current_state = State.SPAWNING

func _physics_process(delta: float) -> void:
	match current_state:
		State.SPAWNING:
			_process_spawning(delta)
		State.COLLECTING:
			_process_collecting(delta)

func _process_spawning(_delta: float) -> void:
	_velocity *= friction
	global_position += _velocity
	if _velocity.length() < stop_threshold:
		_enter_idle()

func _enter_idle() -> void:
	current_state = State.IDLE
	_velocity = Vector2.ZERO
	_start_pulse()
	# Check if player is already overlapping
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			_start_collecting(body)
			return

func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate:a", pulse_min_alpha, 0.6)
	_pulse_tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _on_body_entered(body: Node2D) -> void:
	if current_state == State.IDLE:
		_start_collecting(body)

func _start_collecting(body: Node2D) -> void:
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
	var dir: Vector2 = (_target_body.global_position - global_position).normalized()
	_velocity += dir * magnet_acceleration * delta
	if _velocity.length() > magnet_max_speed:
		_velocity = _velocity.normalized() * magnet_max_speed
	global_position += _velocity * delta
	# Scale down as we approach
	var dist: float = global_position.distance_to(_target_body.global_position)
	scale = Vector2.ONE * clampf(dist / 50.0, 0.3, 1.0)
	if dist < 10.0:
		GameManager.add_gold(value)
		queue_free()
```

**Step 2: Run project validation**

Run: `just check`
Expected: No parse errors

**Step 3: Commit**

```
git add scenes/gold/gold.gd
git commit -m "feat(gold): add state machine with spawning and magnetic collection"
```

---

### Task 2: Update MonsterSpawner to use burst velocity

**Files:**
- Modify: `scenes/game/monster_spawner.gd`

**Step 1: Add burst exports and update `_on_monster_died`**

In `monster_spawner.gd`, add two exports after `gold_per_kill`:

```gdscript
@export var gold_burst_speed_min: float = 150.0
@export var gold_burst_speed_max: float = 300.0
```

Replace the `_on_monster_died` method:

```gdscript
func _on_monster_died(monster: Area2D) -> void:
	var death_pos: Vector2 = monster.global_position
	for _i in gold_per_kill:
		var gold: Area2D = _gold_scene.instantiate()
		gold.global_position = death_pos
		var angle: float = randf() * TAU
		var speed: float = randf_range(gold_burst_speed_min, gold_burst_speed_max)
		var burst_vel: Vector2 = Vector2.from_angle(angle) * speed
		get_parent().add_child(gold)
		gold.start_spawning(burst_vel)
```

Note: `start_spawning()` must be called after `add_child()` so the gold node is in the tree.

**Step 2: Run project validation**

Run: `just check`
Expected: No parse errors

**Step 3: Commit**

```
git add scenes/game/monster_spawner.gd
git commit -m "feat(monster-spawner): burst velocity on gold drops instead of position offsets"
```

---

### Task 3: Write tests for gold state machine

**Files:**
- Create: `core/tests/test_gold.gd`

**Step 1: Write tests**

```gdscript
extends GutTest

var _gold_scene: PackedScene = preload("res://scenes/gold/gold.tscn")

func test_gold_starts_in_idle_state():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	assert_eq(gold.current_state, gold.State.IDLE)

func test_start_spawning_sets_state():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.start_spawning(Vector2(100, 0))
	assert_eq(gold.current_state, gold.State.SPAWNING)

func test_start_spawning_sets_velocity():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	var vel: Vector2 = Vector2(200, 100)
	gold.start_spawning(vel)
	assert_eq(gold.spawn_velocity, vel)

func test_spawning_applies_friction():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.start_spawning(Vector2(200, 0))
	var start_pos: Vector2 = gold.global_position
	# Simulate one physics frame
	gold._process_spawning(0.016)
	assert_ne(gold.global_position, start_pos, "Gold should have moved")

func test_spawning_transitions_to_idle_when_slow():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.start_spawning(Vector2(1, 0))  # Very slow, below threshold
	gold._process_spawning(0.016)
	assert_eq(gold.current_state, gold.State.IDLE)

func test_idle_gold_ignores_body_during_spawning():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.start_spawning(Vector2(200, 0))
	# Simulate body entering during SPAWNING
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	gold._on_body_entered(dummy)
	assert_eq(gold.current_state, gold.State.SPAWNING, "Should stay in SPAWNING")

func test_body_entered_during_idle_starts_collecting():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	assert_eq(gold.current_state, gold.State.IDLE)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	gold._on_body_entered(dummy)
	assert_eq(gold.current_state, gold.State.COLLECTING)

func test_collecting_moves_toward_target():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.global_position = Vector2(100, 0)
	var target: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(target)
	target.global_position = Vector2.ZERO
	gold._start_collecting(target)
	var start_dist: float = gold.global_position.distance_to(target.global_position)
	gold._process_collecting(0.1)
	var end_dist: float = gold.global_position.distance_to(target.global_position)
	assert_lt(end_dist, start_dist, "Gold should move closer to target")
```

**Step 2: Run tests to verify they pass**

Run: `just check` then run GUT tests (if available via command line, otherwise defer to manual verification)
Expected: All tests pass

**Step 3: Commit**

```
git add core/tests/test_gold.gd
git commit -m "test(gold): add state machine tests for spawning and collecting"
```

---

### Task 4: Manual play-test verification

**No files changed.** This is a manual verification step.

**Checklist for designer/developer:**
- [ ] Kill a monster → gold bursts outward in random directions, decelerates, and stops
- [ ] Gold at rest has a subtle alpha pulse
- [ ] Walk near stopped gold → gold accelerates toward player, scales down, collected
- [ ] Gold spawned by GoldSpawner during day starts in IDLE (no burst) and can be collected normally
- [ ] Gold dropped in SPAWNING state cannot be collected until it stops
- [ ] UI gold label updates correctly with "+N" delta animation (unchanged behavior)
