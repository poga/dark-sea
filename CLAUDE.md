# CLAUDE.md

Godot 4 game template with TDD, signal-driven architecture, and reusable components with scenes.

## Godot Best Practices

**Designer-friendly scenes**: Build components with `@export` variables for tweaking in Inspector. Designers compose games by arranging scenes and adjusting parameters. Designers should not editing code.

**Nested scene architecture**: Compose complex scenes from smaller, focused sub-scenes. Each scene = single responsibility.

**Signal communication**: Connect scenes via signals. Parent connects to child signals. Avoid direct cross-scene method calls.

## Quick Start

```bash
just test                    # Run all tests (must pass before any PR)
just scene <name>.tscn       # Run a specific scene
```

## Architecture

**Signal-driven updates**: GameManager singleton emits signals → UI scenes react.
- Singletons in `core/` for state management
- Scenes in `scenes/` for UI and rendering
- Tests in `core/tests/` using GUT framework

Look at existing components in `scenes/` for patterns.

## Development Rules

**Testing**: NO MOCKS. Test real behavior with real data. All tests must pass.

**Changes**: Minimal and focused. Don't refactor unless asked. Add tests for new code.

## Conventions

Find patterns by reading existing code:
- `core/game_manager.gd` - singleton pattern, signal definitions
- `scenes/NumberLabel/` - scene component patterns, tweens, exports
- `core/tests/test_game_manager.gd` - test structure, signal watching
