# Gold Hover-Rise Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a RISING state to gold pickups — gold hovers upward, pauses briefly, then starts the magnet chase.

**Architecture:** Insert a RISING state between IDLE and COLLECTING in the existing gold state machine. RISING uses a tween to move gold upward, pause, then callback into COLLECTING. No changes to COLLECTING or SPAWNING logic.

**Tech Stack:** GDScript, Godot 4 tweens, GUT test framework

---

### Task 1: Update existing test expectation

The test `test_body_entered_during_idle_starts_collecting` currently expects COLLECTING on body_entered. After our change, body_entered during IDLE should enter RISING instead. Update this test first.

**Files:**
- Modify: `core/tests/test_gold.gd:42-49`

**Step 1: Update the test to expect RISING state**

```gdscript
func test_body_entered_during_idle_starts_rising():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	assert_eq(gold.current_state, gold.State.IDLE)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	gold._on_body_entered(dummy)
	assert_eq(gold.current_state, gold.State.RISING)
```

**Step 2: Run test to verify it fails**

Run: `just check`

Expected: FAIL — `State.RISING` does not exist yet.

**Step 3: Commit**

```
git add core/tests/test_gold.gd
git commit -m "test(gold): expect RISING state on body_entered during IDLE"
```

---

### Task 2: Add RISING state enum and exports to gold.gd

Add the RISING value to the State enum and the three new `@export` variables.

**Files:**
- Modify: `scenes/gold/gold.gd:1-15`

**Step 1: Add RISING to enum and new exports**

Change the enum on line 10 from:
```gdscript
enum State { SPAWNING, IDLE, COLLECTING }
```
to:
```gdscript
enum State { SPAWNING, IDLE, RISING, COLLECTING }
```

Add three new exports after `pulse_min_alpha` (line 8):
```gdscript
@export var rise_height: float = 20.0
@export var rise_duration: float = 0.2
@export var rise_pause: float = 0.15
```

Add a `_rise_tween` variable after `_pulse_tween` (line 15):
```gdscript
var _rise_tween: Tween = null
```

**Step 2: Run check to verify it parses**

Run: `just check`

Expected: PASS (no parse errors). The test from Task 1 still fails because `_on_body_entered` still transitions to COLLECTING.

**Step 3: Commit**

```
git add scenes/gold/gold.gd
git commit -m "feat(gold): add RISING state enum and rise exports"
```

---

### Task 3: Implement _enter_rising and wire up the state transition

Change `_on_body_entered` to enter RISING instead of COLLECTING. Implement the `_enter_rising()` method with the tween sequence.

**Files:**
- Modify: `scenes/gold/gold.gd:53-63`

**Step 1: Change _on_body_entered to enter RISING**

Replace the `_on_body_entered` method:
```gdscript
func _on_body_entered(body: Node2D) -> void:
	if current_state == State.IDLE and body is CharacterBody2D:
		_enter_rising(body)
```

Also update `_enter_idle` (line 45) to call `_enter_rising` instead of `_start_collecting`:
```gdscript
func _enter_idle() -> void:
	current_state = State.IDLE
	_velocity = Vector2.ZERO
	_start_pulse()
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			_enter_rising(body)
			return
```

**Step 2: Add _enter_rising method**

Add this method before `_start_collecting`:
```gdscript
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
```

**Step 3: Run the test from Task 1**

Run: `just check`

Expected: PASS — `test_body_entered_during_idle_starts_rising` should pass now.

**Step 4: Commit**

```
git add scenes/gold/gold.gd
git commit -m "feat(gold): add RISING state with hover-pause tween"
```

---

### Task 4: Add RISING-specific tests

Add tests to verify RISING behavior: position changes, transition to COLLECTING, and body_entered ignored during RISING.

**Files:**
- Modify: `core/tests/test_gold.gd`

**Step 1: Add tests**

Append these tests to the file:

```gdscript
func test_rising_ignores_additional_body_entered():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	var dummy1: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy1)
	gold._on_body_entered(dummy1)
	assert_eq(gold.current_state, gold.State.RISING)
	# Second body should be ignored
	var dummy2: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy2)
	gold._on_body_entered(dummy2)
	assert_eq(gold.current_state, gold.State.RISING, "Should stay in RISING")

func test_rise_complete_transitions_to_collecting():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	gold._on_body_entered(dummy)
	assert_eq(gold.current_state, gold.State.RISING)
	# Simulate tween completion
	gold._on_rise_complete()
	assert_eq(gold.current_state, gold.State.COLLECTING)
```

**Step 2: Run tests**

Run: `just check`

Expected: All tests PASS.

**Step 3: Commit**

```
git add core/tests/test_gold.gd
git commit -m "test(gold): add RISING state transition tests"
```

---

### Task 5: Manual verification and final commit

**Step 1: Run full check**

Run: `just check`

Expected: All checks pass, no parse errors.

**Step 2: Manual verification note**

The tween timing (rise_height=20, rise_duration=0.2, rise_pause=0.15) should be verified in-game. These are `@export` variables so the designer can tweak in the Inspector without code changes.

**Step 3: Squash or final commit if needed**

If all tests pass and the implementation is clean, no further commits needed.
