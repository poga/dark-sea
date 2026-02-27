# Hammer Item Design

## Summary

A reusable melee item that deals area damage at the target position. Player clicks to bonk an area, damaging all enemies within the radius. The item stays in inventory after use.

## Behavior

- **UseResult**: KEEP (reusable, stays in inventory)
- **Targeting**: Area damage at click position, no restrictions on where
- **Damage**: 100 to all enemies within bonk radius
- **Preview**: Shows circle at target position (same as turret drop preview pattern)

## Implementation

### Script: `scenes/item/hammer_item.gd`

Extends `base_item.gd` directly (not turret_item). The hammer has no autonomous behavior — it's an instant-use item.

**Exports:**
- `damage: float = 100.0`
- `bonk_radius: float = 80.0`

**Methods:**
- `can_use()` — always returns true
- `has_preview()` — returns true
- `get_preview_position()` — returns `context.target_position`
- `use()` — physics space query (CircleShape2D, collision mask 4) at target position. Calls `take_damage(damage)` on all monsters found. Returns `UseResult.KEEP`.

### Scene: `scenes/item/hammer_item.tscn`

Standard item scene structure:
- PickupState: hammer sprite + label
- InventoryState: smaller hammer sprite
- CollisionShape2D for pickup detection
- No ActiveState needed (item is never placed in world)

### Integration

- Add to `item_spawner.gd` item pool with appropriate weight
- Placeholder sprite/icon until art is ready

## Design Decisions

- **No cooldown**: Keep it simple. Can add later if needed.
- **No visual bonk effect**: Damage numbers from monsters provide feedback. Particles/tweens can be added later.
- **No zone restrictions**: Unlike turrets, hammer can be used anywhere.
- **Extends base_item, not turret_item**: Hammer has no autonomous behavior (timers, detection areas, projectiles). Clean extension of the base contract.
