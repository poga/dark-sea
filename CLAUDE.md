# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Architecture Patterns

All implementations follow the TDD approach.

## Signal-Driven UI Updates
- Use Godot singletons for global game state management
- Use scenes for interaction and rendering
- Implement signals for reactive UI updates instead of polling
- Pattern: GameManager singleton emits signals, UI scenes connect to signals

## Scene Management
- leverage Godot's scene hierarchy for rendering. Instantiate scenes and connect with signals for dynamic updates
- Create reusable scene components
- Use direct positioning for grid layouts instead of container layouts when precise control is needed

## Screen-Relative Sizing
- Use ratios relative to screen size for responsive layouts
- Pattern: `const CELL_SIZE_RATIO: float = 0.018  # 1.8% of screen width`
- Calculate actual sizes: `screen_size.x * CELL_SIZE_RATIO`

## Layout Timing
- Wait for proper layout before calculations using `await get_tree().process_frame`
- Pattern for deferred setup:
```gdscript
func _ready() -> void:
    # Setup non-layout dependent things
    await get_tree().process_frame
    await get_tree().process_frame
    # Now do layout calculations
```

## Godot Singletons
- Register in project.godot: `GameManager="*res://core/game_manager.gd"`
- Extend Node for signal capability
- Global access pattern: `GameManager.method_name()`



## File Structure

```
/
├── project.godot          # Godot project configuration
├── icon.svg              # Project icon
├── Makefile              # Build tasks (test command)
├── core/                 # Core game logic (data structures, no UI)
│   ├── game_core.gd      # GameCore action processing system
│   └── test_game_core.gd # GUT tests for GameCore
├── docs/
│   ├── design.md         # Complete game design document
│   └── tasks.md          # 20 milestone breakdown
├── .godot/               # Godot editor files (ignored)
└── [future directories]  # view/, ui/, scenes/ will be added during development
```

# Development

When developing tests:
- **NEVER use mocks** - they are useless and hide real bugs. Test real behavior, real data, and real user interactions.
- Use actual implementations and real data structures. The goal is to test that software works for real users in real scenarios.
- Test what users see and experience, not internal implementation details.
- Write minimal tests that cover core functionality. Focus on user behavior, not code coverage.

When developing:
- don't make unnecessary changes to the codebase unless absolutely needed. Focus on implementing the requested features or fixes.
- always add tests for changes, but follow the same principles: NO MOCKS, test real user behavior and actual functionality.

### Testing
Use `just test` to validate the implementation. All tests must pass before considering any implementation complete.

For `just scene <scene_name>.tscn` you should always specify the scene filename you want to test instead of a directory
