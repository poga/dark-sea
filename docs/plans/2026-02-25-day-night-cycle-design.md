# Day/Night Cycle Design

## Overview

The game alternates between two phases:
- **Day (退潮/low tide):** Items spawn on the sea. Player walks and picks them up, places turrets.
- **Night (漲潮/high tide):** Monsters spawn. Turrets attack them.

## Approach: GameManager-Centric

All cycle state and timing lives in the GameManager singleton. Scenes react to signals.

## GameManager — Phase State & Signals

New state:
- `enum Phase { DAY, NIGHT }`
- `var current_phase: Phase`
- `@export var day_duration: float = 30.0`
- `@export var night_duration: float = 30.0`

New signals:
- `day_started` — emitted when day phase begins
- `night_started` — emitted when night phase begins
- `phase_changed(phase: Phase)` — emitted on every transition

Timing: A single Timer node (child of GameManager). On timeout, phase flips and timer restarts with the new phase's duration.

API:
- `start_cycle()` — begins at DAY, starts the timer
- `get_current_phase() -> Phase`

## Item Spawning — Script-Based Item Pool + Area2D Spawn Region

**ItemSpawner** (`scenes/game/item_spawner.gd`):

Item pool and rules defined directly in the script for designer readability:
```gdscript
var item_pool = [
    { scene = preload("res://scenes/item/item.tscn"), weight = 3 },
    { scene = preload("res://scenes/item/aoe_item.tscn"), weight = 1 },
]
var items_per_day: int = 4
```

Spawn area defined in the scene:
- `@export var spawn_area: Area2D` — reference to an Area2D in the main scene
- The Area2D has a CollisionShape2D (rectangle) that designers visually resize/reposition in the editor
- At spawn time, the script samples random points within the shape's bounds

Responsibilities:
- Connects to `GameManager.day_started` → spawns items at random positions within spawn area
- Connects to `GameManager.night_started` → removes uncollected pickup-state items
- Tracks spawned items; turret-placed items are unaffected

Main scene changes:
- Remove hardcoded Item1-4 nodes
- Add Area2D node (`ItemSpawnArea`) with rectangular CollisionShape2D covering the sea region
- Add ItemSpawner node, wire `spawn_area` export to the Area2D

## Monster Spawning (Night Phase)

Rework `test_spawner.gd`:
- Connects to `GameManager.night_started` → starts spawning monsters
- Connects to `GameManager.day_started` → stops spawning, removes remaining monsters
- Existing timer-based logic (one monster every `spawn_interval` seconds) stays the same
- Spawner only active during night phase

## Turret Behavior

No changes to turret/item code. Turrets are phase-agnostic — the cycle controls what's on the field, not turret behavior. Items placed as turrets persist across cycles.

## Phase UI

A Label node in the main scene:
- Connects to `GameManager.phase_changed` → updates text to "Day" or "Night"
- Positioned at top of screen
- No timer display, no animations

## Game Flow

1. Game starts → GameManager calls `start_cycle()`, begins DAY
2. DAY starts → `day_started` emitted
   - ItemSpawner spawns batch of items in spawn area
   - Monster spawner stops, remaining monsters removed
   - Player picks up items, places turrets
3. Day timer expires → NIGHT starts, `night_started` emitted
   - ItemSpawner removes uncollected pickup-state items
   - Monster spawner starts
   - Turrets fire at monsters
4. Night timer expires → DAY starts, cycle repeats from step 2

Main scene gets a script that calls `GameManager.start_cycle()` on `_ready()`.
