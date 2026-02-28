# Pickup Tween to Toolbar — Design

## Goal

When an item is picked up, a visual clone (sprite) tweens from the item's world position to the corresponding toolbar slot in screen space. Gives satisfying feedback that the item entered the toolbar.

## Constraints

- No scaling during tween — just a juicy slide
- Clone approach: game logic (item removal, inventory storage) happens instantly; a visual-only sprite flies to the toolbar
- Screen space: tween happens in the UI CanvasLayer so camera movement doesn't affect it

## Architecture

### New signal on GameManager

```gdscript
signal pickup_tween_requested(texture: Texture2D, screen_pos: Vector2, slot: int)
```

Emitted from `try_pickup()` after capturing the item's screen position and icon texture, before the item is removed from the scene tree.

### Modified: GameManager.try_pickup()

Before removing the item from its parent:
1. Capture `item.global_position`
2. Convert to screen position via viewport canvas transform
3. Get `item.inventory_icon`
4. After storing the item, emit `pickup_tween_requested(texture, screen_pos, slot)`

### Modified: Toolbar

New public method:

```gdscript
func get_slot_center(slot: int) -> Vector2
```

Returns the global screen position of the center of the given slot's icon area. Used by the tween layer to know where to animate to.

### New: PickupTweenLayer

A `Control` node added as a child of the UI CanvasLayer in `main.tscn`.

Script:
- Connects to `GameManager.pickup_tween_requested`
- On signal: creates a `TextureRect` with the icon texture at `screen_pos`
- Gets target from `Toolbar.get_slot_center(slot)` (toolbar accessed via tree)
- Tweens position with `TRANS_BACK` + `EASE_OUT` over ~0.35s
- `queue_free()` the TextureRect on completion

Export:
- `@export var duration: float = 0.35` — designer-tweakable tween duration

## Data Flow

```
Player enters PickupZone
  → GameManager.try_pickup(item)
    → capture screen_pos from item.global_position
    → remove item, store in inventory, emit inventory_changed (existing)
    → emit pickup_tween_requested(texture, screen_pos, slot) (new)
      → PickupTweenLayer spawns TextureRect at screen_pos
      → tweens to Toolbar.get_slot_center(slot)
      → queue_free() on completion
```

## Files Changed

| File | Change |
|------|--------|
| `core/game_manager.gd` | Add signal, capture screen pos in try_pickup, emit signal |
| `scenes/ui/toolbar.gd` | Add `get_slot_center(slot)` method |
| `scenes/ui/pickup_tween_layer.gd` | New script — spawns and tweens sprites |
| `scenes/ui/pickup_tween_layer.tscn` | New scene — Control node with script |
| `scenes/game/main.tscn` | Add PickupTweenLayer as child of UI CanvasLayer |

## Testing

- GUT test: verify `pickup_tween_requested` signal emits with correct slot on pickup
- Manual: verify the visual tween looks right, feels juicy, and lands on the correct slot
