# Dummy Target with Damage Display - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a hold-to-damage target that displays floating damage numbers via a reusable DamageDisplay component.

**Architecture:** DamageDisplay component handles label spawning and PopNumberLabel visibility. DummyTarget (Area2D) detects hold input. demo.gd manages damage logic and tick timing.

**Tech Stack:** Godot 4, GDScript, Tween animations, Area2D input handling.

---

### Task 1: Create DamageDisplay Script

**Files:**
- Create: `scenes/DamageDisplay/damage_display.gd`

**Step 1: Create the directory**

Run: `mkdir -p scenes/DamageDisplay`

**Step 2: Write damage_display.gd**

```gdscript
extends Node2D

const BasicFloatLabel = preload("res://scenes/NumberLabel/basic_float_label.tscn")
const SpecialFloatLabel = preload("res://scenes/NumberLabel/special_float_label.tscn")

@export var idle_timeout: float = 1.0

@onready var basic_pos: Marker2D = $BasicLabelPosition
@onready var special_pos: Marker2D = $SpecialLabelPosition
@onready var pop_label: Node2D = $PopLabelPosition/PopNumberLabel

var idle_timer: float = 0.0
var is_active: bool = false

func _ready() -> void:
	pop_label.visible = false

func _process(delta: float) -> void:
	if is_active:
		idle_timer += delta
		if idle_timer >= idle_timeout:
			_hide_pop_label()

func show_basic(amount: int) -> void:
	_ensure_active()
	_spawn_label(BasicFloatLabel, basic_pos.global_position, amount)
	pop_label.add(amount)
	_reset_idle_timer()

func show_special(amount: int) -> void:
	_ensure_active()
	_spawn_label(SpecialFloatLabel, special_pos.global_position, amount)
	pop_label.add(amount)
	_reset_idle_timer()

func reset() -> void:
	_hide_pop_label()

func _ensure_active() -> void:
	if not is_active:
		is_active = true
		pop_label.value = 0
		pop_label.update_label()
		pop_label.visible = true

func _hide_pop_label() -> void:
	is_active = false
	pop_label.visible = false
	idle_timer = 0.0

func _reset_idle_timer() -> void:
	idle_timer = 0.0

func _spawn_label(scene: PackedScene, pos: Vector2, amount: int) -> void:
	var label: Label = scene.instantiate()
	label.text = str(amount)
	label.global_position = pos
	get_tree().root.add_child(label)
```

**Step 3: Validate script syntax**

Run: `just check`
Expected: No errors for damage_display.gd

**Step 4: Commit**

```bash
git add scenes/DamageDisplay/damage_display.gd
git commit -m "feat: add DamageDisplay script for label spawning"
```

---

### Task 2: Create DamageDisplay Scene

**Files:**
- Create: `scenes/DamageDisplay/damage_display.tscn`

**Step 1: Write damage_display.tscn**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/DamageDisplay/damage_display.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://scenes/NumberLabel/PopNumberLabel.tscn" id="2_pop"]

[node name="DamageDisplay" type="Node2D"]
script = ExtResource("1_script")

[node name="BasicLabelPosition" type="Marker2D" parent="."]
position = Vector2(0, -50)

[node name="SpecialLabelPosition" type="Marker2D" parent="."]
position = Vector2(50, -50)

[node name="PopLabelPosition" type="Marker2D" parent="."]
position = Vector2(0, -80)

[node name="PopNumberLabel" parent="PopLabelPosition" instance=ExtResource("2_pop")]
```

**Step 2: Validate scene**

Run: `just check`
Expected: No errors

**Step 3: Commit**

```bash
git add scenes/DamageDisplay/damage_display.tscn
git commit -m "feat: add DamageDisplay scene with marker positions"
```

---

### Task 3: Add DummyTarget and DamageDisplay to demo.tscn

**Files:**
- Modify: `scenes/demo.tscn`

**Step 1: Update demo.tscn**

Add these sections to the file:

After the ext_resource declarations, add:
```
[ext_resource type="Texture2D" uid="uid://icon" path="res://icon.svg" id="4_icon"]
[ext_resource type="PackedScene" path="res://scenes/DamageDisplay/damage_display.tscn" id="5_damage"]
```

Before the connection declarations, add:
```
[node name="DummyTarget" type="Area2D" parent="."]
position = Vector2(270, 480)
input_pickable = true

[node name="Sprite2D" type="Sprite2D" parent="DummyTarget"]
texture = ExtResource("4_icon")
scale = Vector2(0.5, 0.5)

[node name="CollisionShape2D" type="CollisionShape2D" parent="DummyTarget"]

[sub_resource type="RectangleShape2D" id="rect_shape"]
size = Vector2(64, 64)

[node name="DamageDisplay" parent="." instance=ExtResource("5_damage")]
position = Vector2(270, 480)
```

Update the CollisionShape2D to use the sub_resource:
```
[node name="CollisionShape2D" type="CollisionShape2D" parent="DummyTarget"]
shape = SubResource("rect_shape")
```

Add signal connections:
```
[connection signal="input_event" from="DummyTarget" to="." method="_on_dummy_target_input_event"]
[connection signal="mouse_exited" from="DummyTarget" to="." method="_on_dummy_target_mouse_exited"]
```

**Step 2: Validate scene**

Run: `just check`
Expected: No errors

**Step 3: Commit**

```bash
git add scenes/demo.tscn
git commit -m "feat: add DummyTarget and DamageDisplay to demo scene"
```

---

### Task 4: Add Hold-to-Damage Logic to demo.gd

**Files:**
- Modify: `scenes/demo.gd`

**Step 1: Add constants and state at top of file**

After the existing const declarations, add:
```gdscript
const TICK_INTERVAL: float = 0.1
const BASIC_DAMAGE_MIN: int = 19
const BASIC_DAMAGE_MAX: int = 25
const SPECIAL_DAMAGE_MIN: int = 130
const SPECIAL_DAMAGE_MAX: int = 160
const SPECIAL_PROC_CHANCE: float = 0.1

var is_holding_target: bool = false
var tick_accumulator: float = 0.0
```

**Step 2: Add _process function**

```gdscript
func _process(delta: float) -> void:
	if is_holding_target:
		tick_accumulator += delta
		while tick_accumulator >= TICK_INTERVAL:
			tick_accumulator -= TICK_INTERVAL
			_deal_damage_tick()

func _deal_damage_tick() -> void:
	var basic_damage: int = randi_range(BASIC_DAMAGE_MIN, BASIC_DAMAGE_MAX)
	$DamageDisplay.show_basic(basic_damage)

	if randf() < SPECIAL_PROC_CHANCE:
		var special_damage: int = randi_range(SPECIAL_DAMAGE_MIN, SPECIAL_DAMAGE_MAX)
		$DamageDisplay.show_special(special_damage)
```

**Step 3: Add input handlers**

```gdscript
func _on_dummy_target_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_holding_target = event.pressed
		if not event.pressed:
			tick_accumulator = 0.0

func _on_dummy_target_mouse_exited() -> void:
	is_holding_target = false
	tick_accumulator = 0.0
```

**Step 4: Validate script**

Run: `just check`
Expected: No errors

**Step 5: Commit**

```bash
git add scenes/demo.gd
git commit -m "feat: add hold-to-damage logic for DummyTarget"
```

---

### Task 5: Manual Testing

**Step 1: Run the game**

Run: `godot --path . scenes/demo.tscn` (or open in editor and press F5)

**Step 2: Verify behavior**

Checklist:
- [ ] DummyTarget (Godot icon) visible in scene
- [ ] Hold click on target spawns basic_float_label continuously
- [ ] Labels spawn at correct marker positions
- [ ] PopNumberLabel appears on first damage, accumulates total
- [ ] ~10% of ticks also spawn special_float_label
- [ ] PopNumberLabel hides after 1 second of no damage
- [ ] Release mouse stops damage
- [ ] Mouse exit stops damage
- [ ] Next hold session resets PopNumberLabel to 0

**Step 3: Adjust marker positions if needed**

Open demo.tscn in editor, adjust DamageDisplay child Marker2D positions visually.

**Step 4: Final commit if adjustments made**

```bash
git add -A
git commit -m "chore: adjust DamageDisplay marker positions"
```
