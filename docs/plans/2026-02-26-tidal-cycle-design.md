# Tidal Cycle Design (SCA-31)

Enhance the day/night cycle with an animated tide that ebbs during day and rises during night, revealing and hiding items/gold based on tide position.

## Approach

Tide Scene with Script (Approach A). The Tide ColorRect owns its own animation via tweens and emits signals. Spawners react to tide signals to show/hide items. GameManager stays focused on phase state.

## Tide Component

Script `tide.gd` attached to the existing `Tide` ColorRect in `main.tscn`.

**Exports:**
- `ebb_duration: float = 5.0` - time for tide to recede
- `rise_duration: float = 5.0` - time for tide to rise
- `ebb_ratio: float = 0.8` - fraction of width that recedes (0.8 = 80% recedes, 20% stays)

**Signals:**
- `tide_position_changed(left_edge_x: float)` - fires during tween with current left edge x
- `tide_ebbed` - ebb animation complete
- `tide_risen` - rise animation complete

**Behavior:**
- On `GameManager.day_started`: tween `offset_left` rightward by `width * ebb_ratio`, emitting `tide_position_changed` continuously. Emit `tide_ebbed` on completion.
- On `GameManager.night_started`: tween `offset_left` back to original, emitting `tide_position_changed` continuously. Emit `tide_risen` on completion.
- Right edge (`offset_right`) stays fixed.

## Item Spawner Changes

**Day (ebb):**
1. On `day_started`: spawn all items hidden (`visible = false`).
2. On `tide_position_changed(x)`: for each hidden item, if `item.global_position.x > x`, set `visible = true`.
3. Items appear one-by-one as tide recedes past them.

**Night (rise):**
1. On `tide_position_changed(x)`: for each visible PICKUP-state item in sea zone, if `item.global_position.x > x`, hide it.
2. On `tide_risen`: destroy all hidden sea-zone items.

Only items in `State.PICKUP` within the sea zone are affected. Turret-placed items persist.

Needs `@export var tide_path: NodePath`.

## Gold Spawner Changes

Same pattern as item spawner:
- Day: spawn gold hidden, reveal when tide edge passes.
- Night: hide gold when tide covers, destroy on `tide_risen`.

Needs `@export var tide_path: NodePath`.

## Signal Flow

```
GameManager.day_started
  -> Tide: starts ebb tween
  -> ItemSpawner: spawns items (hidden)
  -> GoldSpawner: spawns gold (hidden)

Tide.tide_position_changed(x)
  -> ItemSpawner: reveals items where item.x > x
  -> GoldSpawner: reveals gold where gold.x > x

Tide.tide_ebbed
  (informational)

GameManager.night_started
  -> Tide: starts rise tween

Tide.tide_position_changed(x) [during rise]
  -> ItemSpawner: hides pickup items where item.x > x
  -> GoldSpawner: hides gold where gold.x > x

Tide.tide_risen
  -> ItemSpawner: destroys hidden sea-zone items
  -> GoldSpawner: destroys hidden sea-zone gold
```

## Testing

- Tide ebb/rise signals fire correctly
- Items spawn hidden and reveal as tide position passes them
- Night cleanup only happens after `tide_risen`
- Turret-placed items unaffected by tide

## Design Decisions

- **Partial ebb**: Tide covers entire sea zone at night, recedes ~80% during day (20% always underwater). Configurable via `ebb_ratio`.
- **Position-synced reveals**: Items reveal/hide when the tide edge physically passes their x-position.
- **Designer-configurable durations**: `ebb_duration` and `rise_duration` are `@export` vars.
- **Gold follows same pattern**: Both items and gold are tide-synced.
