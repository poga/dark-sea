# Inventory & Pickup Redesign

## Problem

Dropping items on beach immediately re-picks them up because the drop position (player center) overlaps with PickupZone (radius 50). The `_recently_dropped` workaround patches the symptom. The beach zone adds complexity without clear gameplay value.

## Design

### Zone Simplification

Remove Beach zone. Two zones remain:

- **Tower** — drop places turret
- **Sea** — no dropping allowed

`can_drop()` checks for Tower zone specifically (not "not sea"). `drop_item()` always calls `item.drop()` since only Tower allows dropping.

`drop_as_pickup()` stays on `base_item.gd` for future use but is not called from any current code path.

### Auto-pickup: State Check

`_on_pickup_zone_area_entered` only auto-picks items in `PICKUP` state (sea spawns). Items in `TURRET` state are ignored by auto-pickup.

### Long-press Turret Reclaim

New interaction to pick up placed turrets:

- Player walks within PickupZone range of a placed turret
- Holds interact key for `reclaim_hold_time` (~1 second, `@export`)
- On completion: turret calls `store_in_inventory()`, returns to first empty slot
- If inventory full: nothing happens
- Releasing key early or walking out of range cancels the reclaim

Tracking:
- `_turrets_in_range: Array[Area2D]` — turrets detected by PickupZone
- `_reclaim_target: Area2D` — turret currently being reclaimed (nearest)
- `_reclaim_timer: float` — accumulated hold time

### Cleanup

Remove:
- `ZoneType.BEACH` enum value
- Beach zone from `main.tscn`
- `_recently_dropped` array and all references in `player.gd`
- Beach-specific test cases in `test_zone_dropping.gd`

### Unchanged

- 8-slot inventory, slot switching, toolbar UI
- Sea item spawning + auto-pickup for PICKUP-state items
- Item state machine (PICKUP, TURRET, INVENTORY)
- `drop_as_pickup()` method (kept, unused)
- Signal-driven architecture
