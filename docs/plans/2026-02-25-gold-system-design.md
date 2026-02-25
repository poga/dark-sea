# Gold System Design (SCA-25)

## Overview

Add gold as a collectible resource. Gold spawns during day in the sea zone, drops from killed monsters, and is auto-collected by player proximity. Gold is a future currency stored in GameManager.

## Design Decisions

- **Future currency**: Gold stored in GameManager with signals for other systems to access
- **Auto-pickup**: Player collects gold by walking near it (no interact key)
- **Zone-based cleanup**: Gold in sea zone is washed away at night; gold on beach persists
- **Separate spawner**: GoldSpawner is its own node, following single-responsibility pattern
- **Rename test_spawner**: `test_spawner.gd` becomes `monster_spawner.gd`

## Components

### 1. GameManager — Gold State

Add to `core/game_manager.gd`:
- `var gold: int = 0`
- `signal gold_changed(new_amount: int)`
- `func add_gold(amount: int)` — increments gold, emits signal

### 2. Gold Pickup Scene (`scenes/gold/gold.tscn`)

- **Area2D** root (collision layer: items, mask: player)
  - **ColorRect** — small yellow square
  - **CollisionShape2D** — CircleShape2D for proximity detection
- Script: on player body entered → `GameManager.add_gold(value)`, `queue_free()`
- `@export var value: int = 1`

### 3. GoldSpawner (`scenes/game/gold_spawner.gd`)

- `@export var spawn_area_path: NodePath` — same ItemSpawnArea (sea zone)
- `@export var sea_zone_path: NodePath` — reference to SeaZone for cleanup check
- `@export var gold_per_day: int = 5`
- Connects to `GameManager.day_started` → spawns gold in spawn area
- Connects to `GameManager.night_started` → removes gold inside sea zone only
- Tracks all spawned gold for cleanup

### 4. MonsterSpawner (rename from test_spawner)

- Rename `test_spawner.gd` → `monster_spawner.gd`, update main.tscn
- On each monster spawn, connect to its `died` signal
- On monster death: spawn gold pickups at death position
- `@export var gold_per_kill: int = 3`
- Monster-drop gold registered with GoldSpawner for zone-based cleanup

### 5. Gold UI Label

- Label in UI CanvasLayer alongside PhaseLabel
- Connects to `GameManager.gold_changed` signal
- Displays gold count

## Data Flow

```
Day starts → GoldSpawner spawns gold in sea zone
Player walks over gold → gold.gd detects → GameManager.add_gold() → gold_changed → UI updates
Monster dies → MonsterSpawner callback → spawns gold at death position
Night starts → GoldSpawner removes gold in sea zone, beach gold persists
```

## Spawner Architecture

| Spawner | Phase | Spawns | Cleanup |
|---------|-------|--------|---------|
| ItemSpawner | Day | Items (turrets) | Night: all uncollected |
| GoldSpawner | Day | Gold pickups | Night: sea zone only |
| MonsterSpawner | Night | Monsters | Day: all remaining |
