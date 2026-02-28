# Tide Z-Order Fix Design

## Problem

The Tide ColorRect is the last child of `Main` in `main.tscn`, so it renders on top of all world-space nodes (Player, Monsters, Items). It should render above terrain but below active entities.

## Approach

Use `z_index` properties combined with scene tree reordering.

## Z-Index Layering

| Layer | z_index | Nodes |
|-------|---------|-------|
| Terrain | 0 | Zones (TowerZone, SeaZone) |
| Ground items | 0 | Dynamically spawned items, gold, drops |
| Tide | 1 | Tide ColorRect |
| Active entities | 2 | Player, Monsters, DamageNumbers |
| Drop preview | 10 | Player/DropPreview (existing) |
| UI | CanvasLayer | UI node (existing) |

## Changes

1. **`main.tscn`** — Move `Tide` node from last child to after `Zones` (before `Player`). Set `z_index = 1`.
2. **`main.tscn`** — Set `z_index = 2` on `Player`, `Monsters`, and `DamageNumbers` nodes.

No script changes needed. Dynamically spawned items/gold/drops inherit default `z_index = 0`, rendering below Tide for a submerged effect.
