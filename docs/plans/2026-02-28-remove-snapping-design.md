# Remove Target Vector Snapping

## Summary

Replace the cardinal direction snapping mechanism with raw continuous vector input for `facing_direction`. Items will drop in any direction (360 degrees) instead of only 4 cardinal directions.

## Changes

1. **Remove `snap_to_cardinal()` function** from `player.gd`
2. **Normalize raw look vector** — `facing_direction = look.normalized()`, preserving last direction when input is zero
3. **Update tests** — replace cardinal snapping assertions with continuous vector assertions
4. **No changes needed** to `get_drop_position()` or drop preview — they already work with any unit vector
