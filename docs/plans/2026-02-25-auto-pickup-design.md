# Auto-Pickup Items on Proximity

## Summary

Replace manual Space-key pickup with automatic pickup when the player walks near items. Items are collected instantly when entering the PickupZone (radius 50). If inventory is full, items are silently ignored.

## Decisions

- All items auto-pickup (no item-type distinction)
- Inventory full: ignore silently, item stays on ground
- Space/interact key removed entirely; Q (drop) remains

## Approach

Signal-driven: use existing `area_entered` signal on PickupZone to trigger pickup immediately. No timers or polling.

## Changes

### `player.gd`

1. Modify `_on_pickup_zone_area_entered(area)` — after tracking in `_items_in_range`, call `_try_auto_pickup(area)` to find empty slot and pick up
2. Remove `interact` input handling from `_unhandled_input()`
3. Remove `pick_up_nearest_item()` and `get_nearest_item()` (no longer needed)
4. Keep `_find_empty_slot()` (used by auto-pickup)
5. Keep `_items_in_range` tracking (needed for edge case below)

### Edge case: drop frees slot near uncollected items

When player drops an item while standing near uncollected items, attempt auto-pickup of items in `_items_in_range` after the drop.

### `project.godot`

Remove `interact` input action mapping (Space key).

### Signals

No changes — `item_picked_up` and `inventory_changed` fire through existing pickup flow.

## Testing

- Remove interact-key-based pickup tests
- Test: item auto-picked-up when entering range
- Test: item ignored when inventory full
- Test: dropping item near uncollected items triggers auto-pickup
