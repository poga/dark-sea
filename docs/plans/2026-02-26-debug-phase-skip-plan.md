# Debug Phase Skip Button Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a debug button that skips to the next day/night phase with normal tide transitions.

**Architecture:** Add `skip_to_next_phase()` to GameManager that stops the timer and triggers the existing timeout handler. Add a Button node in the UI CanvasLayer of `main.tscn`.

**Tech Stack:** GDScript, Godot 4, GUT testing framework

---

### Task 1: Add skip_to_next_phase() to GameManager (TDD)

**Files:**
- Test: `core/tests/test_game_manager.gd`
- Modify: `core/game_manager.gd`

**Step 1: Write the failing test**

Add to `core/tests/test_game_manager.gd`:

```gdscript
func test_skip_to_next_phase_transitions_from_day_to_night():
	GameManager.start_cycle()
	watch_signals(GameManager)
	GameManager.skip_to_next_phase()
	assert_eq(GameManager.current_phase, GameManager.Phase.NIGHT)
	assert_signal_emitted(GameManager, "night_started")

func test_skip_to_next_phase_transitions_from_night_to_day():
	GameManager.start_cycle()
	GameManager._on_phase_timer_timeout()  # go to night
	watch_signals(GameManager)
	GameManager.skip_to_next_phase()
	assert_eq(GameManager.current_phase, GameManager.Phase.DAY)
	assert_signal_emitted(GameManager, "day_started")
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `skip_to_next_phase` not defined

**Step 3: Implement skip_to_next_phase()**

Add to `core/game_manager.gd` after the `_on_phase_timer_timeout()` method (line 49):

```gdscript
func skip_to_next_phase() -> void:
	_phase_timer.stop()
	_on_phase_timer_timeout()
```

**Step 4: Run tests to verify they pass**

Run: `just test`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add core/game_manager.gd core/tests/test_game_manager.gd
git commit -m "feat(game-manager): add skip_to_next_phase for debug use"
```

---

### Task 2: Add debug button to UI

**Files:**
- Modify: `scenes/game/main.tscn`

**Step 1: Add Button node to main.tscn**

Add a Button node under the `UI` CanvasLayer in `scenes/game/main.tscn`. Position it at the bottom-right corner. The button text should be ">>". Connect its `pressed` signal to `GameManager.skip_to_next_phase` via the scene script or inline.

Add to the end of `scenes/game/main.tscn`:

```
[node name="DebugSkipPhase" type="Button" parent="UI"]
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -80.0
offset_top = -40.0
grow_horizontal = 0
grow_vertical = 0
text = ">>"
```

Then connect the button's pressed signal to GameManager in `scenes/game/main.gd` `_ready()`:

```gdscript
%DebugSkipPhase.pressed.connect(GameManager.skip_to_next_phase)
```

Note: The `%` unique name syntax requires adding `unique_name_in_owner = true` to the node definition in the .tscn file.

**Step 2: Run validation**

Run: `just check`
Expected: No errors

**Step 3: Commit**

```bash
git add scenes/game/main.tscn scenes/game/main.gd
git commit -m "feat(ui): add debug skip-phase button"
```
