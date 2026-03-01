# Swing Down Animation Design

## Problem

When using a held item (placement, craft, dig, attack), there's no visual feedback. The effect just happens instantly. We need a universal "swing down" animation that plays on item use.

## Design

### Motion

A tween-based downward swing on the held item node, three beats:

1. **Down-swing**: Item rotates ~45 degrees downward with ease-in. Duration is configurable per item via `@export swing_duration`.
2. **Impact pause**: Brief hold (~0.05s) at the bottom of the swing. The item's `use()` effect triggers here.
3. **Instant snap-back**: Item rotation resets to 0 immediately. No easing, no animation.

Rotation direction follows player facing: clockwise when facing right, counter-clockwise when facing left.

### Integration with item system

The swing wraps the existing `use()` flow in `base_item.gd`:

- `@export var swing_duration: float = 0.3` -- per-item configurable
- `@export var swing_angle: float = 45.0` -- per-item configurable
- `var is_swinging: bool` -- blocks `can_use()` while true

**Flow:**
1. Player presses "use" -> `GameManager.use_item()` -> `item.can_use(context)` returns false if swinging
2. `item.play_swing()` starts the downswing tween
3. At the bottom: brief pause, then tween callback calls `item.use(context)`
4. Instant snap-back to origin rotation
5. `is_swinging = false`

Existing `use()` implementations (hammer, turret, etc.) remain unchanged. They fire at the impact point instead of immediately.

### Signals

- `item_use_attempted` -- emitted at the start (before swing)
- `item_used` / `item_use_failed` -- emitted at the impact point

### Testing

- Swing blocks re-use: `can_use()` returns false during swing
- Effect fires at impact: `use()` is called after swing, not at start
- Swing completes: item returns to original rotation after swing
- Configurable duration: different `swing_duration` values work

No visual feel tests -- delegate to manual verification.

## Approach

Tween-based animation in `base_item.gd`. Matches existing project patterns (pickup tweens, number labels). No new scenes or nodes needed.
