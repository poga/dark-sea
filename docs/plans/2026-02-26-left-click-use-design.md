# Left-Click = Use = Drop Item

## Summary

Replace the `drop` (Q key) input with a `use` (left-click) action. Items define what "use" means via a `use()` method. Default behavior: drop as turret.

## Input Changes

- Remove `drop` action (Q key) from `project.godot`
- Add `use` action mapped to left mouse button

## Item Changes (`base_item.gd`)

- Add `use(player) -> bool` method
- Default implementation: delegates to player's drop logic, returns success/failure
- Subclasses override `use()` for different behaviors (consumables, abilities, etc.)

## Player Changes (`player.gd`)

- `_unhandled_input`: listen for `use` action instead of `drop`
- When `use` pressed: call `active_item.use(self)` instead of calling `drop_item()` directly
- `use()` receives player reference so items can access drop position, facing direction, etc.
- Keep `drop_item()` as public method — it's the mechanic, `use()` is the intent

## Drop Preview

Unchanged. Preview circle still follows facing direction, validates zones.

## Signals

No new signals. Existing `item_dropped`, `inventory_changed` fire as before since `use()` delegates to existing drop logic.

## Future Extensibility

Item subclasses override `use()` for custom behaviors:
- Consumables: heal, buff, etc.
- Abilities: area effects, temporary boosts
- Different placement modes
