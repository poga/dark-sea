# Camera Lookahead Design

## Goal

Replace the centered camera with a lookahead camera that shifts toward the character's facing direction, giving the player more visibility ahead. Inspired by Don't Starve's subtle mouse-based camera offset.

## Approach

Script on the existing Camera2D child node using the built-in `offset` property. Camera2D stays as a child of Player — position tracking is automatic, and we only animate the offset toward the facing direction.

## Component

New script `scenes/player/camera_lookahead.gd` attached to the Camera2D node in `player.tscn`.

### Behavior

1. Each frame in `_process`, read the parent Player's `facing_direction`
2. Compute target offset: `facing_direction * lookahead_distance`
3. Lerp the current `offset` toward the target using `lookahead_smoothing * delta`
4. When facing direction is zero, offset smoothly returns to center

### Exported Parameters

- `lookahead_distance: float = 60.0` — how far ahead the camera shifts (pixels)
- `lookahead_smoothing: float = 3.0` — how fast the camera transitions to new offset (higher = snappier)

## Cleanup

- Remove `camera_smoothing_speed` export from `player.gd`
- Keep `position_smoothing_enabled` and `position_smoothing_speed` on Camera2D node
- Delete `docs/plans/2026-02-25-framed-camera-design.md` (SCA-29 design, no longer needed)

## What Stays the Same

- Camera2D remains a child of Player in `player.tscn`
- Position smoothing handles base follow behavior
- `facing_direction` on Player is read-only from camera's perspective — no signals needed
