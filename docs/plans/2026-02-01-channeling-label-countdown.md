# Channeling Label Countdown Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add countdown functionality to ChannelingLabel that masks the ActiveLabel from right-to-left over a configurable duration.

**Architecture:** Wrap ActiveLabel in a Control with `clip_contents=true`, then tween the container width from full to zero. Script on root node handles exports, signals, and tween lifecycle.

**Tech Stack:** Godot 4, GDScript, Tween API

---

### Task 1: Restructure Scene - Add ClipContainer

**Files:**
- Modify: `scenes/channeling_label.tscn`

**Step 1: Modify the scene file**

Update `channeling_label.tscn` to add ClipContainer between root and ActiveLabel:

```tscn
[gd_scene load_steps=2 format=3 uid="uid://dnsevteknmmr4"]

[ext_resource type="Script" path="res://scenes/channeling_label.gd" id="1_script"]

[node name="ChannelingLabel" type="Node2D"]
script = ExtResource("1_script")

[node name="BGLabel" type="Label" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -97.0
offset_top = -17.5
offset_right = 97.0
offset_bottom = 17.5
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 10
text = "CHANNELING"

[node name="ClipContainer" type="Control" parent="."]
clip_contents = true
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -97.0
offset_top = -17.5
offset_right = 97.0
offset_bottom = 17.5
grow_horizontal = 2
grow_vertical = 2

[node name="ActiveLabel" type="Label" parent="ClipContainer"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(0.9561816, 0.8063388, 0.37932798, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 10
text = "CHANNELING"
```

**Step 2: Validate scene parses**

Run: `just check`
Expected: No errors related to channeling_label.tscn

**Step 3: Commit**

```bash
git add scenes/channeling_label.tscn
git commit -m "restructure channeling label with ClipContainer for masking"
```

---

### Task 2: Create Script with Exports and Signals

**Files:**
- Create: `scenes/channeling_label.gd`

**Step 1: Create the script file**

```gdscript
extends Node2D

signal channeling_finished
signal channeling_cancelled

@export var text: String = "CHANNELING"
@export var duration: float = 3.0
@export var autostart: bool = false

@onready var _bg_label: Label = $BGLabel
@onready var _clip_container: Control = $ClipContainer
@onready var _active_label: Label = $ClipContainer/ActiveLabel

var _tween: Tween
var _initial_width: float

func _ready() -> void:
	_bg_label.text = text
	_active_label.text = text
	_initial_width = _clip_container.size.x

	if autostart:
		start()
```

**Step 2: Validate script parses**

Run: `just check`
Expected: No errors

**Step 3: Commit**

```bash
git add scenes/channeling_label.gd
git commit -m "add channeling label script with exports and signals"
```

---

### Task 3: Implement start() Method

**Files:**
- Modify: `scenes/channeling_label.gd`

**Step 1: Add start method**

Add after `_ready()`:

```gdscript
func start() -> void:
	if _tween != null:
		return  # Already running

	_tween = create_tween()
	_tween.tween_property(_clip_container, "size:x", 0.0, duration)
	_tween.finished.connect(_on_channeling_complete)


func _on_channeling_complete() -> void:
	channeling_finished.emit()
	queue_free()
```

**Step 2: Validate script parses**

Run: `just check`
Expected: No errors

**Step 3: Commit**

```bash
git add scenes/channeling_label.gd
git commit -m "implement start() and countdown completion"
```

---

### Task 4: Implement cancel() Method

**Files:**
- Modify: `scenes/channeling_label.gd`

**Step 1: Add cancel method**

Add after `_on_channeling_complete()`:

```gdscript
func cancel() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

	channeling_cancelled.emit()
	queue_free()
```

**Step 2: Validate script parses**

Run: `just check`
Expected: No errors

**Step 3: Commit**

```bash
git add scenes/channeling_label.gd
git commit -m "implement cancel() for interrupting channeling"
```

---

### Task 5: Manual Verification

**Step 1: Test in Godot Editor**

Open project in Godot. Create a test scene or use existing demo scene:

1. Instance `channeling_label.tscn`
2. In Inspector, set `duration = 3.0`, `autostart = true`
3. Run scene
4. Verify: ActiveLabel shrinks from right-to-left over 3 seconds, then scene removes itself

**Step 2: Test cancel behavior**

1. Create test script that calls `cancel()` after 1 second
2. Verify: Channeling stops, `channeling_cancelled` signal fires, scene removes itself

**Step 3: Test custom text**

1. Set `text = "CASTING"` in Inspector
2. Run scene
3. Verify: Both labels show "CASTING"

**Step 4: Commit any fixes if needed**

---

### Task 6: Final Cleanup

**Step 1: Run full validation**

Run: `just check`
Expected: All checks pass

**Step 2: Commit plan completion**

```bash
git add docs/plans/2026-02-01-channeling-label-countdown.md
git commit -m "complete channeling label countdown implementation"
```
