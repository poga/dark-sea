# Milestone 1: Controllable Character with Item Pickup/Drop

**Issue**: SCA-21 Milestone 1
**Date**: 2026-02-23

## Overview

A controllable 2D character that moves with WASD and can pick up / drop items. Items have two visual states (pickup and turret) represented as separate nodes in the scene tree. Camera follows the character.

## Scene Structure

### Player (`scenes/player/player.tscn`)

Extends **CharacterBody2D**.

```
Player (CharacterBody2D)
├── Sprite2D (icon.svg)
├── Label ("Player")
├── CollisionShape2D
├── PickupZone (Area2D)
│   └── CollisionShape2D (circle radius)
├── HoldPosition (Marker2D) — offset above head
└── Camera2D (position smoothing enabled)
```

**Exports:**
- `speed: float` (default 200.0)

**Behavior:**
- `_physics_process`: read input direction from custom actions, set velocity, `move_and_slide()`
- On `"interact"` pressed:
  - If holding an item: drop it at current position, call `item.drop()`, reparent to world
  - If not holding: find nearest item in PickupZone, call `item.pick_up()`, reparent to HoldPosition

**Signals:**
- `item_picked_up(item)`
- `item_dropped(item, position)`

**Pickup logic:**
- PickupZone tracks overlapping items via `area_entered` / `area_exited`
- When multiple items overlap, pick the closest one to the player's position

### Item (`scenes/item/item.tscn`)

Extends **Area2D**.

```
Item (Area2D)
├── PickupState (Node2D) — visible when on ground
│   ├── Sprite2D (icon.svg)
│   └── Label ("Item Name")
├── TurretState (Node2D) — visible when placed as turret
│   ├── Sprite2D (icon.svg)
│   └── Label ("Item Name")
└── CollisionShape2D
```

**Exports:**
- `item_name: String` (default "Item")

**States:**
- PICKUP: `PickupState` visible, `TurretState` hidden
- TURRET: `PickupState` hidden, `TurretState` visible

Default state: PICKUP (items start on the ground).

**Signals:**
- `picked_up_as_item` — was on ground, player grabbed it
- `picked_up_as_turret` — was placed as turret, player grabbed it back
- `placed_as_turret` — player dropped it, becomes turret

**Methods:**
- `pick_up()`: emit appropriate signal based on current state, switch to PICKUP state
- `drop()`: switch to TURRET state, emit `placed_as_turret`

### Main Scene (`scenes/game/main.tscn`)

```
Main (Node2D)
├── Player (instance of player.tscn)
└── Items (Node2D)
    ├── Item (test instance)
    ├── Item (test instance)
    └── ...
```

Composition only. No script needed for milestone 1. Place a few test items to verify mechanics.

## Input Map

Custom input actions added to `project.godot`:

| Action       | Key     |
|-------------|---------|
| `move_up`    | W       |
| `move_down`  | S       |
| `move_left`  | A       |
| `move_right` | D       |
| `interact`   | Space   |

## Camera

Camera2D as child of Player. Position smoothing enabled with `@export` speed for designer tweaking.

## Sprites

All sprites use `icon.svg` (Godot icon) with a Label node to describe what they are, per SCA-21 requirements.
