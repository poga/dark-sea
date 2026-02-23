# Milestone 2: Playground Zones & Turret Combat

## Overview

Split the playable area into three zones, add turret attack behavior when items are placed in the tower zone, and introduce basic monsters for testing.

## Zone System

Three `Area2D` zones in main scene, left-to-right:

- **TowerZone** (left edge) - narrow strip. Dropping item here = turret state.
- **BeachZone** (middle) - wide area. Dropping item here = stays pickup state.
- **SeaZone** (right) - dropping blocked entirely.

Each zone has a ColorRect background for visual distinction. Zone sizes/positions are `@export` vars.

Player tracks current zone via `area_entered`/`area_exited`. Drop behavior depends on zone:
- TowerZone: `item.drop()` (turret mode)
- BeachZone: `item.drop_as_pickup()` (pickup mode)
- SeaZone: drop action blocked

## Turret Attack Behavior

When item enters turret state, these activate:
- **DetectionArea** (Area2D, circle) with `attack_range` radius detects monsters
- **ShootTimer** fires every `1.0 / attack_rate` seconds
- On tick: find closest monster in detection area, spawn projectile aimed at it

Exported vars on item:
- `attack_range: float = 150.0`
- `attack_rate: float = 1.0` (shots/sec)
- `projectile_speed: float = 300.0`
- `projectile_damage: float = 10.0`

Detection area and timer deactivate when picked up (back to pickup state).

Targeting: `_find_target() -> Node2D` returns closest monster. Method is isolated for future strategy swapping.

## Projectile

New scene `scenes/projectile/projectile.tscn`:
- Root: `Area2D` with small `ColorRect` (8x8) and `CollisionShape2D`
- Receives direction + speed on spawn, travels straight line
- On `area_entered` with monster: calls `monster.take_damage()`, frees itself
- Frees after max lifetime (2s) or leaving screen
- Collision: only masks monster layer (layer 3). No other interactions.
- Spawned as sibling in scene tree (not child of turret)

## Monster

New scene `scenes/monster/monster.tscn`:
- Root: `Area2D` on monster collision layer (layer 3)
- `Sprite2D` (icon.svg, small) + `Label` ("Monster")
- Exports: `hp: float = 30.0`, `speed: float = 50.0`
- Drifts leftward each frame
- `take_damage(amount)`: reduce HP, spawn `basic_float_label` for damage display
- Emits `died` signal at 0 HP, frees itself
- Despawns when exiting left screen edge

## Collision Layers

- Layer 1: Player
- Layer 2: Items
- Layer 3: Monsters
- Layer 4: Projectiles

Projectiles only mask layer 3. Clean separation.

## Scene Composition (main.tscn)

```
Main (Node2D)
├── Zones
│   ├── TowerZone (Area2D + ColorRect)
│   ├── BeachZone (Area2D + ColorRect)
│   └── SeaZone (Area2D + ColorRect)
├── Player
├── Items
├── Monsters
└── TestSpawner (creates a monster every few seconds for testing)
```

## Signal Flow

- Player → Zones: track current zone
- Turret → Projectile: turret spawns projectiles into scene tree
- Projectile → Monster: `area_entered` → `take_damage()` → free
- Monster → Scene: `died` signal for future use, then free

## Changes to Existing Code

- **player.gd**: zone tracking, zone-aware drop logic
- **item.gd**: add `drop_as_pickup()`, turret attack exports, shooting logic
- **item.tscn**: TurretState gets DetectionArea + ShootTimer children

## Tests

- Zone detection: player knows current zone
- Drop behavior per zone: turret in tower zone, pickup on beach, blocked in sea
- Turret targeting: finds closest monster
- Projectile: moves, hits monster, deals damage, frees itself
- Monster: takes damage, dies at 0 HP, drifts left, despawns offscreen
