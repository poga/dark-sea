# Debug Phase Skip Button

## Goal

Add a debug button to skip to the next day/night phase during gameplay, triggering the normal transition (tide animation plays, spawners react).

## Design

### GameManager change

Add `skip_to_next_phase()` method that stops the `_phase_timer` and calls `_on_phase_timer_timeout()`. This reuses existing phase-toggle logic so all signals fire normally.

### UI change

Add a `Button` node under the `UI` CanvasLayer in `main.tscn`. Wire its `pressed` signal to call `GameManager.skip_to_next_phase()`. Position in bottom-right corner to avoid obstructing gameplay.

## Scope

- 1 new method on `GameManager`
- 1 new `Button` node in `main.tscn` with a small script or inline connection
