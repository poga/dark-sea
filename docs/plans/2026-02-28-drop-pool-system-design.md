# Drop Pool System Design

## Problem

Monsters only drop hardcoded gold (3 per kill). Need a flexible drop pool system supporting multiple resource types (gold, bones, scales, etc.) and item drops, driven by data files that designers and AI agents can easily modify.

## Design Decisions

- **Centralized singleton**: All drop logic lives in `DropManager` singleton - one script for all logic, easy for AI agents to modify.
- **JSON data files**: Drop tables defined in `data/drop_tables.json`. AI agents edit this file to rebalance.
- **Independent chance per entry**: Each drop entry rolls independently (not weighted selection). A monster can drop gold AND bones AND an item from one kill.
- **Resources are numeric counters**: Resources (gold, bones, scales) are numbers stored in GameManager, not inventory items.
- **Generalized pickup scene**: Gold pickup scene generalized to `ResourcePickup` - same state machine, parameterized by resource type, icon, and value.
- **Preloaded scenes**: All item scenes referenced in drop tables are preloaded at startup to avoid stutter.
- **Per-monster-type pools**: Each monster type has its own drop table keyed by `monster_type` string.

## Data Format

`data/drop_tables.json`:

```json
{
  "skeleton": {
    "drops": [
      { "type": "gold", "chance": 1.0, "min": 1, "max": 3 },
      { "type": "bones", "chance": 0.3, "min": 1, "max": 2 },
      { "type": "item", "chance": 0.05, "scene": "res://scenes/item/turret_item.tscn" }
    ]
  },
  "sea_creature": {
    "drops": [
      { "type": "gold", "chance": 1.0, "min": 2, "max": 5 },
      { "type": "scales", "chance": 0.5, "min": 1, "max": 1 }
    ]
  }
}
```

- Resource entries: `type` (resource name), `chance` (0.0-1.0), `min`/`max` amount range
- Item entries: `type` = "item", `chance`, `scene` path to item .tscn
- Resource icons follow convention: `res://assets/icons/{type}.png`

## Architecture

### Signal Flow

```
Monster.died(monster_type: String, position: Vector2)
  -> DropManager._on_monster_died(type, position)
     -> rolls each entry: randf() < chance
     -> resource entries: instantiate ResourcePickup scene, set type/icon/value, add to world
     -> item entries: instantiate preloaded item scene, position at death location, add to world
```

### New: DropManager Singleton (`core/drop_manager.gd`)

- Registered in `project.godot` autoload
- `_ready()`: loads `data/drop_tables.json`, preloads all referenced item scenes
- `roll_drops(monster_type: String, position: Vector2)`: rolls drops and spawns them
- Needs reference to game world node (parent for spawned pickups/items)
- `drop_tables: Dictionary` - parsed JSON data
- `preloaded_scenes: Dictionary` - scene path -> PackedScene

### Modified: GameManager (`core/game_manager.gd`)

- Replace `gold: int` with `var resources: Dictionary = {}`
- `add_resource(type: String, amount: int)` - increments and emits signal
- `get_resource(type: String) -> int` - returns current amount
- New signal: `resource_changed(type: String, new_amount: int)`
- Keep backward compat: `add_gold()` calls `add_resource("gold", amount)`

### Modified: Monster (`scenes/monster/monster.gd`)

- Add `@export var monster_type: String = "default"`
- Change `died` signal to `died(monster_type: String, position: Vector2)`
- Emit with type and global_position on death

### Modified: MonsterSpawner (`scenes/game/monster_spawner.gd`)

- Remove gold spawning from `_on_monster_died()`
- Connect monster `died` signal to `DropManager.roll_drops()` instead

### Refactored: ResourcePickup (`scenes/pickup/resource_pickup.gd`)

- Generalize from gold.gd
- Same state machine: SPAWNING -> IDLE -> RISING -> COLLECTING
- New exports: `resource_type: String`, `icon: Texture2D`, `value: int`
- On collect: `GameManager.add_resource(resource_type, value)`
- Sprite set from `icon` at runtime

### Updated UI: GoldLabel

- Listen for `resource_changed` signal (filtered for "gold") instead of `gold_changed`

### Updated: GoldSpawner

- Use new ResourcePickup scene instead of gold scene

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `core/drop_manager.gd` | New | Singleton handling all drop logic |
| `data/drop_tables.json` | New | Drop table data file |
| `core/game_manager.gd` | Modify | Generic resource system replacing gold-only |
| `scenes/monster/monster.gd` | Modify | Add monster_type, update died signal |
| `scenes/game/monster_spawner.gd` | Modify | Remove gold spawning, delegate to DropManager |
| `scenes/pickup/resource_pickup.gd` | New (from gold.gd) | Generalized pickup with resource type/icon/value |
| `scenes/pickup/resource_pickup.tscn` | New (from gold.tscn) | Generalized pickup scene |
| `scenes/gold/` | Remove | Replaced by scenes/pickup/ |
| `scenes/ui/gold_label.gd` (or similar) | Modify | Use resource_changed signal |
| `scenes/game/gold_spawner.gd` | Modify | Use ResourcePickup scene |
| `project.godot` | Modify | Register DropManager autoload |
