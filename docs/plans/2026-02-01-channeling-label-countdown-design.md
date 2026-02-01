# Channeling Label Countdown Design

## Overview

Add countdown functionality to the `ChannelingLabel` scene. The label displays a duration-based countdown with a visual masking effect that reveals the background label as time depletes.

## Exported Properties

```gdscript
@export var text: String = "CHANNELING"
@export var duration: float = 3.0  ## Countdown duration in seconds
@export var autostart: bool = false  ## Start countdown on _ready()
```

## Scene Structure

```
ChannelingLabel (Node2D)
├── BGLabel (Label) - unchanged
└── ClipContainer (Control) - clip_contents = true
    └── ActiveLabel (Label) - moved inside container
```

The `ClipContainer` wraps `ActiveLabel` and uses `clip_contents` to mask it. During countdown, the container's width shrinks from full to zero, progressively revealing `BGLabel` underneath.

## Signals

```gdscript
signal channeling_finished  ## Emitted when countdown completes
signal channeling_cancelled  ## Emitted when cancel() is called
```

## Public Methods

```gdscript
func start() -> void
    ## Begins the countdown. Called automatically if autostart = true.
    ## Ignored if already running.

func cancel() -> void
    ## Stops countdown, emits channeling_cancelled, then queue_free()
```

## Behavior

### Countdown Flow
1. `start()` creates a tween animating `ClipContainer.size.x` from full width to 0
2. Tween runs for `duration` seconds
3. On completion: emit `channeling_finished`, then `queue_free()`

### Cancellation Flow
1. `cancel()` kills active tween (if any)
2. Emit `channeling_cancelled`
3. Call `queue_free()`

### Edge Cases
- `start()` when already running: ignored (early return)
- `cancel()` when not running: emits signal and frees silently
- Multiple `cancel()` calls: safe via null-check

## Usage Example

```gdscript
var label = channeling_label_scene.instantiate()
label.text = "CASTING"
label.duration = 2.5
label.channeling_finished.connect(_on_cast_complete)
label.channeling_cancelled.connect(_on_cast_interrupted)
add_child(label)
label.start()
```

## Implementation

- Script: `scenes/channeling_label.gd` attached to scene root
- `_ready()`: set label texts, store initial width, call `start()` if autostart
- Tween: `TRANS_LINEAR` for consistent countdown feel
