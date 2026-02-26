# Prevent Item Drop When Overlapping Turrets

## Problem

Players can currently drop items on top of existing turrets. Items should not be placeable where their collision shape overlaps an already-placed turret.

## Design

Modify `can_drop()` in `player.gd` to use a circle shape query (`PhysicsShapeQueryParameters2D` + `CircleShape2D`) instead of a point query. The circle matches the item's collision radius. If the shape overlaps any existing item in `TURRET` state, the drop is blocked.

### Changes

**`scenes/player/player.gd` — `can_drop()`**:
1. Create a `CircleShape2D` matching the item collision radius (~20).
2. Run `intersect_shape()` at the drop position.
3. Check results for both conditions:
   - At least one result is a TOWER zone (existing logic).
   - No result is an item in `TURRET` state (new check).
4. Return `true` only if both conditions pass.

### What stays the same

- Drop preview already calls `can_drop()` every frame — it will automatically show red when overlapping.
- No new signals, scenes, or nodes.
- No changes to item or zone code.

## Approach

**Shape cast query** (Approach B from brainstorming): true radius-based overlap detection using Godot's physics system, not just a point check.
