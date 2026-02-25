# Inventory System Design

Linear: SCA-27

## Overview

Replace the player's single held item with an 8-slot inventory. A bottom-of-screen toolbar shows all slots. The player selects a slot and the active item displays on their head (current hold behavior). Dropping drops the active slot's item.

## Player State Changes (player.gd)

Replace `held_item: Area2D = null` with:

- `INVENTORY_SIZE = 8` constant
- `inventory: Array[Area2D]` — 8 elements, null = empty slot
- `active_slot: int = 0`
- Signal `inventory_changed(slot: int, item: Area2D)` — emitted on pickup/drop
- Signal `active_slot_changed(slot: int)` — emitted on slot switch

### Pickup

- Find the first empty slot in `inventory`
- If no empty slot, block pickup (do nothing)
- Place item in that slot, call `item.store_in_inventory()`
- If it's the active slot, reparent to `$HoldPosition`
- Emit `inventory_changed(slot, item)`

### Drop

- Drop the item at `active_slot` (if any)
- Zone logic unchanged: TOWER → `drop()`, BEACH → `drop_as_pickup()`, SEA → blocked
- Set `inventory[active_slot] = null`
- Emit `inventory_changed(active_slot, null)`

### Slot Switching

- On switch: remove current active item from `$HoldPosition` (if any)
- Set `active_slot` to new value
- If new slot has an item, reparent it to `$HoldPosition`
- Emit `active_slot_changed(slot)`
- Wrapping: `slot_prev` from 0 goes to 7, `slot_next` from 7 goes to 0

### Scene Tree Management

- Active slot item: child of `$HoldPosition`, visible in INVENTORY state
- Non-active slot items: removed from scene tree, stored only in the array
- This prevents turret systems from activating on inactive held items

## Item State: INVENTORY (base_item.gd)

Add third state to the enum:

```
enum State { PICKUP, TURRET, INVENTORY }
```

Each item scene gets an `$InventoryState` node alongside `$PickupState` and `$TurretState`. Designers control how items look when held above the player's head (active inventory slot) by editing this node.

New export for toolbar icon:

```
@export var inventory_icon: Texture2D
```

Designers assign a texture per item type. The toolbar displays this icon in each slot.

New method:

```
func store_in_inventory() -> void:
    current_state = State.INVENTORY
    _update_state_visuals()
    _update_turret_systems()
```

`_update_state_visuals()` updated to show only the matching state node for all three states.

## Input Actions (project.godot)

- `slot_1` through `slot_8` — keyboard keys 1-8 (direct slot selection)
- `slot_prev` / `slot_next` — for gamepad bumpers or d-pad (cyclic slot switching)

## Toolbar UI (scenes/ui/toolbar.tscn)

Pure lightweight UI — no SubViewports, no item reparenting.

- `HBoxContainer` anchored to bottom-center of screen
- 8 `PanelContainer` children, each containing: slot number `Label`, `TextureRect` for item's `inventory_icon`
- Active slot highlighted with distinct style (e.g. border color)
- `@export var player_path: NodePath` for wiring
- Connects to `inventory_changed` and `active_slot_changed` signals
- On `inventory_changed(slot, item)`: update slot's TextureRect from `item.inventory_icon` (or clear if null)
- On `active_slot_changed(slot)`: move highlight to new slot

Single source of truth: player's `inventory` array. Toolbar reads item properties, never owns items.

## What Stays the Same

- Item `pick_up()`, `drop()`, `drop_as_pickup()` methods unchanged
- Zone logic unchanged
- Monster, projectile, gold systems unchanged
- GameManager unchanged
- Existing `item_picked_up` and `item_dropped` signals still emitted
