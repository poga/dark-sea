# Framed Camera Design (SCA-29)

## Problem

Camera currently follows the player directly with position smoothing. This feels rigid. Instead, implement a "safe zone" where the camera stays still while the player moves within it, only following when the player reaches the edges.

## Approach

Use Godot Camera2D's built-in drag margin system. No custom scripts needed.

## Changes

### `scenes/player/player.tscn` - Camera2D node

Set these properties on the existing Camera2D:

- `drag_horizontal_enabled = true`
- `drag_vertical_enabled = true`
- `drag_left_margin = 0.3`
- `drag_right_margin = 0.3`
- `drag_top_margin = 0.3`
- `drag_bottom_margin = 0.3`
- Keep `position_smoothing_enabled = true` for smooth catch-up

### `scenes/player/player.gd`

Remove the `camera_smoothing_speed` export and the `_ready()` line that sets `$Camera2D.position_smoothing_speed`. Smoothing speed is set directly on the Camera2D node.

## Behavior

- Player moves freely within the center ~40% of the screen (safe zone)
- Camera stays still while player is in the safe zone
- When player reaches a margin edge, camera smoothly follows
- Both horizontal and vertical axes use the same margins

## Testing

Visual/feel only - no unit tests. Manual verification:
1. Camera stays still when player moves within the safe zone
2. Camera smoothly follows when player moves outside the safe zone
3. Works correctly in all three zones (Tower, Beach, Sea)
