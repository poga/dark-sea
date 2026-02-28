# Gold Hover-Rise Design

## Goal

Add an anticipation beat to gold collection: gold hovers upward, pauses briefly at the apex, then starts the existing magnet chase. Makes pickup feel more satisfying.

## Current State

Gold has a 3-state machine: `SPAWNING → IDLE → COLLECTING`. When the player enters the gold's collision area during IDLE, it immediately transitions to COLLECTING (magnet pull toward player). This works but the transition from sitting still to chasing feels abrupt.

## Design

### New State: RISING

Insert a **RISING** state between IDLE and COLLECTING:

```
SPAWNING → IDLE → RISING → COLLECTING
```

**Trigger:** `body_entered` signal fires while gold is in IDLE state (same trigger as current COLLECTING).

**Behavior:**
1. Kill pulse tween, set alpha to 1.0
2. Store target body reference
3. Run a tween sequence:
   - Rise upward by `rise_height` pixels over `rise_duration` seconds (EASE_OUT for floaty deceleration at top)
   - Pause for `rise_pause` seconds
   - Callback: transition to COLLECTING
4. Gold does **not** track the player during RISING — it rises in place
5. If target becomes invalid during tween, `queue_free()`

### New Exports

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `rise_height` | float | 20.0 | Pixels to hover upward |
| `rise_duration` | float | 0.2 | Seconds for the rise animation |
| `rise_pause` | float | 0.15 | Seconds to hang at apex before chasing |

### Edge Cases

- **Player moves away during RISING:** Gold completes rise, then COLLECTING chase catches up (magnet is fast)
- **Target freed during RISING:** Check `is_instance_valid()` on tween callback, `queue_free()` if invalid
- **Multiple body_entered during RISING:** Ignored — only IDLE state processes `body_entered`

### Tests

- RISING state entered on body_entered during IDLE
- Gold y-position decreases (moves up) during RISING
- RISING transitions to COLLECTING after tween
- body_entered ignored during RISING and SPAWNING

## Files Changed

- `scenes/gold/gold.gd` — add RISING enum, exports, `_enter_rising()`, tween logic
- `core/tests/test_gold.gd` — tests for RISING state
