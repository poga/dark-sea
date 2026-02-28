# Juicy Gold Pickups Design

## Goal

Make gold pickups feel satisfying with physics-based drop bursts and magnetic collection.

## Current State

Gold is a 16x16 yellow ColorRect. On player proximity it instantly calls `add_gold()` + `queue_free()`. Monster drops place gold at random position offsets. No animation, no feedback beyond the UI delta label.

## Design

### Gold State Machine

Gold gets a 3-state lifecycle: `SPAWNING → IDLE → COLLECTING`.

**SPAWNING**: Gold has a velocity vector. Each physics frame: move by velocity, apply friction (`velocity *= friction`). When speed drops below `stop_threshold`, transition to IDLE. Gold ignores player pickup during this state.

**IDLE**: Gold sits still with a subtle alpha pulse tween (modulate.a oscillates between `pulse_min_alpha` and 1.0). Detectable by player's PickupZone.

**COLLECTING**: Triggered when player's PickupZone overlaps gold in IDLE state. Gold accelerates toward player's `global_position` each frame, capped at `magnet_max_speed`. Scales down proportionally as distance shrinks. On arrival (distance < 5px), calls `GameManager.add_gold(value)` + `queue_free()`.

### Exported Designer Variables (gold.gd)

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `value` | int | 1 | Gold amount (existing) |
| `friction` | float | 0.85 | Velocity multiplier per frame during SPAWNING |
| `stop_threshold` | float | 5.0 | Speed below which SPAWNING → IDLE |
| `magnet_acceleration` | float | 1500.0 | Acceleration toward player during COLLECTING |
| `magnet_max_speed` | float | 600.0 | Max magnetic pull speed |
| `pulse_min_alpha` | float | 0.7 | Idle glow pulse minimum alpha |

### Drop Burst (MonsterSpawner)

Instead of position offsets, give each gold a velocity vector:

```
var angle = randf() * TAU
var speed = randf_range(burst_speed_min, burst_speed_max)
gold.spawn_velocity = Vector2.from_angle(angle) * speed
```

Gold starts at monster death position and flies outward. Friction decelerates naturally.

New exports on MonsterSpawner: `gold_burst_speed_min` (150.0) and `gold_burst_speed_max` (300.0).

### GoldSpawner (Day Spawns)

Environmental gold spawns directly in IDLE state (no burst). No changes needed to GoldSpawner logic beyond ensuring gold starts in IDLE.

### Signal Flow

Current: `body_entered → add_gold → queue_free`

New: `area_entered → set state COLLECTING → _physics_process accelerates toward player → on arrival → add_gold → queue_free`

### What Stays the Same

- `GameManager.add_gold()` and `gold_changed` signal
- GoldLabel / NumberLabel UI
- GoldSpawner day spawn logic
- Player's PickupZone detection

## Files Changed

- `scenes/gold/gold.gd` — state machine, physics movement, magnetic pull
- `scenes/gold/gold.tscn` — export defaults
- `scenes/game/monster_spawner.gd` — burst velocity instead of position offsets
