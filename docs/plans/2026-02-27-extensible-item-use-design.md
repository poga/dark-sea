# Extensible Item Use System Design

## Problem

The current item system couples "using an item" to "placing a turret." Turret logic (DetectionArea, ShootTimer, attack targeting) lives in `base_item.gd`, and `player.gd` orchestrates placement with zone checks and overlap detection. This makes it impossible to create non-turret items (melee weapons, tools, consumables) without modifying core files.

## Goals

- Items define their own behavior: a turret places itself, a sword swings, a shovel digs
- Designer creates new item types by writing a new script + new scene — no changes to base_item or player
- Single USE button triggers different behaviors depending on item type
- Items can be consumed (potion), persistent (sword), or placed (turret) — per-item setting
- Items query and modify game state (gold, phase) through GameManager

## Design

### The Use Contract

Items implement three virtual methods:

```gdscript
# base_item.gd
enum UseResult { NOTHING, KEEP, CONSUME, PLACE }

func can_use(context: Dictionary) -> bool:
    return true

func use(context: Dictionary) -> UseResult:
    return UseResult.CONSUME

func has_preview() -> bool:
    return false

func get_preview_position(context: Dictionary) -> Vector2:
    return context.target_position
```

The `context` dictionary contains spatial/physics info:
- `target_position: Vector2` — where the player is aiming (player pos + facing * drop_distance)
- `player: CharacterBody2D` — player reference
- `zone` — zone type at target position (TOWER, SEA, null)
- `space_state: PhysicsDirectSpaceState2D` — for custom physics queries

Items access game-wide state (gold, phase) directly via the GameManager singleton.

`UseResult` tells GameManager what to do after use():
- `NOTHING` — use failed, don't touch inventory
- `KEEP` — succeeded, item stays in inventory (sword swing, reusable tool)
- `CONSUME` — succeeded, remove item from inventory and free it (potion)
- `PLACE` — succeeded, remove from inventory and place in world at target position (turret)

### Responsibility Split

**Player (input only)**:
- Movement, facing direction
- On USE press: `GameManager.use_active_item(get_drop_position(), self)`
- On slot switch: `GameManager.switch_slot(n)`
- Reports items entering/exiting pickup range to GameManager
- Runs preview each frame by querying active item's `can_use()` and `has_preview()`
- Owns HoldPosition (visual rendering of held item)

**GameManager (state + lifecycle)**:
- Owns `inventory: Array[Area2D]`, `active_slot: int`
- Builds context dictionary from player info
- Calls `item.can_use(context)` and `item.use(context)`
- Handles reparenting based on UseResult
- Manages auto-pickup logic
- Emits inventory and item-use signals

**Item (behavior)**:
- Defines `can_use()` — validation logic (zone checks, gold checks, cooldowns)
- Defines `use()` — execution (spawn effects, deal damage, modify state)
- Defines preview behavior (`has_preview()`, `get_preview_position()`)
- Manages its own internal state (attack timers, cooldowns, animations)

### Signal Flow

```gdscript
# GameManager signals
signal inventory_changed(slot: int, item: Area2D)
signal active_slot_changed(slot: int)
signal item_use_attempted(item: Area2D)
signal item_used(item: Area2D, result: int)
signal item_use_failed(item: Area2D)
```

USE action flow:
```
Player._unhandled_input("use")
  → GameManager.use_active_item(target_pos, player)
    → item_use_attempted.emit(item)
    → context = build_context(target_pos, player)
    → if not item.can_use(context):
        → item_use_failed.emit(item)
        → return
    → result = item.use(context)
    → if result == NOTHING:
        → item_use_failed.emit(item)
    → else:
        → handle reparenting/inventory based on result
        → item_used.emit(item, result)
```

Preview flow (every frame):
```
Player._physics_process()
  → item = GameManager.get_active_item()
  → if item and item.has_preview():
      → context = GameManager.build_context(target_pos, player)
      → preview_pos = item.get_preview_position(context)
      → valid = item.can_use(context)
      → $DropPreview.visible = true
      → $DropPreview.global_position = preview_pos
      → $DropPreview.update_state(valid)
  → else:
      → $DropPreview.visible = false
```

### Item Type Examples

**Turret (turret_item.gd extends base_item.gd)**:
- `can_use()` → checks TOWER zone + no turret overlap (physics query)
- `use()` → returns `PLACE`
- `has_preview()` → `true`
- Scene has DetectionArea, ShootTimer for autonomous attack when placed
- Current `_attack()`, `_find_target()` virtual methods live here

**AOE Turret (aoe_item.gd extends turret_item.gd)**:
- Overrides `_attack()` for area damage (same as current)

**Hypothetical Sword (melee_item.gd extends base_item.gd)**:
- `can_use()` → `true` (always usable)
- `use()` → plays swing animation, damages enemies in arc → returns `KEEP`
- `has_preview()` → `false`

**Hypothetical Potion (consumable_item.gd extends base_item.gd)**:
- `can_use()` → `true`
- `use()` → heals player, returns `CONSUME`
- `has_preview()` → `false`

## File Changes

### Modified files

| File | Change |
|------|--------|
| `base_item.gd` | Strip turret logic. Add `can_use()`, `use() -> UseResult`, `has_preview()`, `get_preview_position()`. Rename State.TURRET → State.ACTIVE. Remove turret-specific exports (attack_range, etc.) |
| `item.tscn` | Remove TurretState children (DetectionArea, ShootTimer). Rename TurretState → ActiveState |
| `player.gd` | Remove inventory array, `can_drop()`, `drop_item()`, `use_item()`, pickup bookkeeping. Keep input, movement, facing, preview rendering. Delegate to GameManager |
| `game_manager.gd` | Add inventory management, `use_active_item()`, `build_context()`, `try_pickup()`, reparenting, new signals |
| `toolbar.gd` | Connect to GameManager signals instead of Player signals |
| `aoe_item.gd` | Extends `turret_item.gd` instead of `base_item.gd` |
| `item_spawner.gd` | Update pool to reference `turret_item.tscn` |
| Tests | Update to reflect new GameManager API and signal names |

### New files

| File | Purpose |
|------|---------|
| `scenes/item/turret_item.gd` | Turret behavior extracted from base_item: DetectionArea, ShootTimer, `_attack()`, `_find_target()`, zone-based `can_use()` |
| `scenes/item/turret_item.tscn` | Scene inheriting item.tscn, adds TurretState children |

### Unchanged

- Main scene hierarchy (`main.tscn`)
- Zone system (`zone.gd`, tower/sea zones)
- Monster/projectile system
- Day/night phase logic
- Toolbar visual structure
- DropPreview scene (used by player, data from item)
