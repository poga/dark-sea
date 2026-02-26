# Character Facing Design (SCA-32)

## Overview

Add a facing direction to the player character that controls where items are dropped. The facing direction follows the mouse cursor or right joystick, snapped to 4 cardinal directions. A preview circle shows the target drop location when holding an item.

## Requirements

1. Character has a facing direction (north/east/south/west) controlled by mouse or right joystick
2. Items drop in the facing direction at a configurable distance
3. A small circle previews the drop location when holding an item
4. Drop zone restriction remains: target must be inside TOWER zone

## Design

### Facing Direction Tracking

Add to `player.gd`:
- `var facing_direction: Vector2 = Vector2.RIGHT` — always one of UP/DOWN/LEFT/RIGHT
- `@export var drop_distance: float = 80.0` — offset distance for item drops

Input priority in `_physics_process`:
1. Right joystick (`look_up/down/left/right` input actions) — overrides mouse when active
2. Mouse position — `(get_global_mouse_position() - global_position)` as fallback

Snapping: raw direction snapped to nearest cardinal direction by comparing `abs(x)` vs `abs(y)`, then using sign.

New input actions in `project.godot`: `look_up`, `look_down`, `look_left`, `look_right` for right joystick.

No visual sprite changes for now — facing is internal only.

### Drop Preview Circle

Child node in Player scene:
- Positioned at `global_position + facing_direction * drop_distance`
- Visible only when `has_active_item()` is true
- Green/white when target is inside TOWER zone, red when outside
- Lightweight: `_draw()` circle or simple Sprite2D

### Directional Item Drop

Modify `drop_item()`:
- Calculate `drop_position = global_position + facing_direction * drop_distance`
- Validate target position is inside TOWER zone (replaces current player-position check)
- If valid: drop item at `drop_position`
- If invalid: reject drop (no action)

Update `can_drop()` to check target position instead of player position.

### Testing

- Facing snap logic: verify cardinal direction snapping
- Drop position calculation: verify offset math
- Zone validation: verify drops rejected outside tower zone, accepted inside
- Visual preview: manual verification
