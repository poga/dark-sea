# Dummy Target with Damage Display

## Overview

Add a clickable target to demo.tscn that deals continuous damage while held. Damage is displayed using existing label components via a new reusable DamageDisplay component.

## Behavior

**Hold-to-damage:**
- Click and hold on target to deal damage
- Ticks every 0.1s (10 ticks/second)
- Release or mouse exit stops damage

**Each damage tick:**
1. Deal 19-25 basic damage → spawn basic_float_label
2. 10% chance: deal additional 130-160 special damage → spawn special_float_label
3. Add all damage to PopNumberLabel

**PopNumberLabel visibility:**
- Hidden by default
- Shows on first damage tick (resets to 0)
- Hides after 1 second of no damage

## Scene Structure

### DamageDisplay Component (new)

`scenes/DamageDisplay/damage_display.tscn`:

```
DamageDisplay (Node2D)
├── BasicLabelPosition (Marker2D)
├── SpecialLabelPosition (Marker2D)
└── PopLabelPosition (Marker2D)
    └── PopNumberLabel (instance)
```

**damage_display.gd:**

```gdscript
@export var idle_timeout: float = 1.0
```

**Public methods:**
- `show_basic(amount: int)` - Spawns basic_float_label at BasicLabelPosition, adds to PopNumberLabel
- `show_special(amount: int)` - Spawns special_float_label at SpecialLabelPosition, adds to PopNumberLabel
- `reset()` - Hides and resets PopNumberLabel to 0

**Internal behavior:**
- First call to show_basic/show_special: reset PopNumberLabel to 0, make visible
- Each call resets idle timer
- Hide PopNumberLabel when idle timer reaches idle_timeout

### DummyTarget (in demo.tscn)

```
DummyTarget (Area2D)
├── Sprite2D (icon.svg - Godot logo)
└── CollisionShape2D (RectangleShape2D)
```

### Updated demo.tscn hierarchy

```
Demo (Node2D)
├── ... existing nodes ...
├── DummyTarget (Area2D)
│   ├── Sprite2D
│   └── CollisionShape2D
└── DamageDisplay (instance)
```

## demo.gd Implementation

**Constants:**
```gdscript
const TICK_INTERVAL: float = 0.1
const BASIC_DAMAGE_MIN: int = 19
const BASIC_DAMAGE_MAX: int = 25
const SPECIAL_DAMAGE_MIN: int = 130
const SPECIAL_DAMAGE_MAX: int = 160
const SPECIAL_PROC_CHANCE: float = 0.1
```

**State:**
```gdscript
var is_holding_target: bool = false
var tick_accumulator: float = 0.0
```

**Signal handlers:**
- `_on_dummy_target_input_event()` - Set is_holding_target on left mouse press/release
- `_on_dummy_target_mouse_exited()` - Set is_holding_target to false

**_process(delta):**
- If holding: accumulate delta, deal damage each TICK_INTERVAL
- Damage logic: roll basic, call show_basic(), roll for special proc, call show_special() if proc

## Files to Create/Modify

**New files:**
- `scenes/DamageDisplay/damage_display.tscn`
- `scenes/DamageDisplay/damage_display.gd`

**Modified files:**
- `scenes/demo.tscn` - Add DummyTarget and DamageDisplay nodes
- `scenes/demo.gd` - Add hold-to-damage logic
