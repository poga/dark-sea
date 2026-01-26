# PopNumberLabel Animation Enhancement

## Goal

Make the pop animation more dynamic with random variation, rotation, and snappier timing.

## Design

### Animation Behavior

1. **On value change**: Instantly snap to peak state (no animation to peak)
2. **Peak state**: Random scale + random rotation
3. **Settle back**: Animate from peak → normal over 0.15s using `EASE_OUT` + `TRANS_BACK`

### Randomness

- **Scale**: Base `impact_scale` ±40% (e.g., 1.5 base → 0.9x to 2.1x range)
- **Rotation**: -20° to +20° (random direction each pop)
- **Duration**: Consistent 0.15s for predictable rhythm

### Scene Setup (PopNumberLabel.tscn)

- Label anchors: all set to 0.5 (centered)
- `text_horizontal_alignment`: CENTER
- `grow_horizontal`: GROW_DIRECTION_BOTH
- `grow_vertical`: GROW_DIRECTION_BOTH

This removes the need for code-calculated `pivot_offset`.

### Export Variables

```gdscript
@export var impact_scale: float = 1.5
@export var scale_variation: float = 0.4      ## ±40% randomness
@export var max_rotation_degrees: float = 20.0
@export var animation_duration: float = 0.15
```

## Implementation

1. Update `PopNumberLabel.tscn` with centered anchors and alignment
2. Update `pop_number_label.gd`:
   - Remove `pivot_offset` calculation and `await` in `_ready()`
   - Add rotation tween to `_create_impact_animation()`
   - Add randomness to scale and rotation
   - Reduce default duration to 0.15s
