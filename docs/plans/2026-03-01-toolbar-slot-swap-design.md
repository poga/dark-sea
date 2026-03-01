# Toolbar Slot Swap Design

## Goal

Allow players to rearrange items in the toolbar by clicking slots, Stardew Valley style.

## Interaction Model

Two-state interaction on the live toolbar during gameplay:

```
IDLE ──[click non-empty slot]──→ HOLDING
HOLDING ──[click same slot]──→ IDLE (cancel)
HOLDING ──[click other slot]──→ IDLE (swap/move)
HOLDING ──[click outside toolbar]──→ IDLE (drop item into world)
```

### Behavior

- **Pick up**: Click a non-empty slot. Item icon disappears from slot, appears on cursor.
- **Swap**: Click another slot (empty or occupied). Items swap positions. If target is empty, item just moves.
- **Cancel**: Click the same slot or press ESC. Item returns to original slot.
- **Drop**: Click outside the toolbar. Item drops into the world at `get_drop_position()`.
- **Keyboard slot switch while holding**: Cancels the hold first.

### Cursor Visual

A semi-transparent `TextureRect` (80% opacity) follows `get_global_mouse_position()` during HOLDING state. Source slot appears empty while held.

## Architecture (Approach A: Toolbar-owned)

### GameManager Changes

Two new methods:

**`swap_slots(a: int, b: int)`** — Swaps `inventory[a]` and `inventory[b]`. Emits `inventory_changed` for both slots. Handles `HoldPosition` reparenting if either slot is the active slot.

**`drop_item_from_slot(slot: int, target_position: Vector2)`** — Removes item from inventory, places it in the world at `target_position`. Emits `inventory_changed(slot, null)`. Reuses existing place/drop logic from `_apply_item_use`.

### Toolbar Changes

New state tracking:
- `held_slot: int = -1` (-1 = IDLE)
- Each slot's `PanelContainer` gets `mouse_filter = MOUSE_FILTER_STOP`
- `gui_input` signal connected on each slot for click detection
- New `CursorItem` node (`TextureRect` child of a `CanvasLayer`) follows mouse in `_process`

### Player Changes

**Drop distance derived from pickup radius:**

Replace `@export var drop_distance: float = 80.0` with:
```
@export var drop_margin: float = 30.0
```

`get_drop_distance()` returns `$PickupZone/CollisionShape2D.shape.radius + drop_margin`. This ensures dropped items always land beyond the pickup zone, even when the radius is tweaked by a designer.

## Signal Flow

```
Pick up (IDLE → HOLDING):
  Toolbar click on non-empty slot
  → held_slot = slot index
  → hide slot icon, show CursorItem
  → no GameManager call (visual only)

Swap/Move (HOLDING → IDLE):
  Toolbar click on another slot
  → GameManager.swap_slots(held_slot, clicked_slot)
    → swap inventory entries
    → emit inventory_changed for both slots
    → handle active_slot reparenting
  → hide CursorItem, held_slot = -1

Drop (HOLDING → IDLE):
  Click outside toolbar
  → GameManager.drop_item_from_slot(held_slot, player.get_drop_position())
    → remove from inventory, reparent to world
    → emit inventory_changed(held_slot, null)
  → hide CursorItem, held_slot = -1

Cancel (HOLDING → IDLE):
  Click same slot or ESC
  → restore slot icon, hide CursorItem, held_slot = -1
```

## Edge Cases

- **Active slot involved in swap**: Update `HoldPosition` child accordingly.
- **ESC / right-click while holding**: Cancel hold, return item to original slot.
- **Keyboard slot switch while holding**: Cancel hold first, then switch.
- **Empty slot click while IDLE**: No-op.
