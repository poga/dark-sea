# CLAUDE.md

Godot 4 game. signal-driven architecture, and reusable components with scenes.

Review game scene to understand how it works

# Development Workflow

**Project validation**: Run `just check` to validate imports and scripts. Use this after making changes to catch parse errors quickly.

**Testing**: NO MOCKS. Test real behavior and system interactions with real data. All tests must pass. Avoid testing specific values designed by designer. delegate to manual verification when needed.

## Linear Task Lifecycle

When working on a Linear ticket (team: `SCA`), follow this state flow:

**`Todo` → `In Progress` → `In Review` → `Done`**

1. **Brainstorming done** — Comment on the ticket with a link to the design doc.
2. **Start implementation** — Move ticket to `In Progress`. Create a branch named `sca-<number>-<short-description>`.
3. **Verification complete** — Create a PR with `Closes SCA-XX` in the description. Move ticket to `In Review`.
4. **Merged** — Merging the PR auto-closes the ticket to `Done`.

Not all work requires a Linear ticket. This workflow only applies when a ticket ID is given.

# Architecture Patterns

## Godot Best Practices

**Designer-friendly scenes**: Build components with `@export` variables for tweaking in Inspector. Designers compose games by arranging scenes and adjusting parameters. Designers should not editing code.

**Nested scene architecture**: Compose complex scenes from smaller, focused sub-scenes, prefer built-in godot scenes and compisition. Each scene = single responsibility.

**Signal communication**: Connect scenes via signals. Parent connects to child signals. Avoid direct cross-scene method calls.

**Explicit type annotations**: Always use explicit types when the inferred type could be ambiguous (e.g., `var dir: Vector2 = vec.normalized()`). Methods like `normalized()` don't have a set return type that Godot can infer.

## Signal-Driven UI Updates
- Use Godot singletons for global game state management
- Use scenes for interaction and rendering
- Implement signals for reactive UI updates instead of polling
- Pattern: GameManager singleton emits signals, UI scenes connect to signals

## Scene Management
- leverage Godot's scene hierarchy for rendering. Instantiate scenes and connect with signals for dynamic updates
- Create reusable scene components

## Godot Singletons
- Register in project.godot: `GameManager="*res://core/game_manager.gd"`
- Extend Node for signal capability
- Global access pattern: `GameManager.method_name()`

# Architecture Examples

**Signal-driven updates**: GameManager singleton emits signals → UI scenes react.
- Singletons in `core/` for state management
- Scenes in `scenes/` for UI and rendering
- Tests in `core/tests/` using GUT framework. Write tests for components, not visual aspects and feels.

Look at existing components in `scenes/` and `core/` for patterns.

- `core/game_manager.gd` - singleton pattern, signal definitions. the core game state and logic should be here
- `scenes/components/NumberLabel/` - UI component patterns, tweens, exports.
- `core/tests/test_game_manager.gd` - test structure, signal watching
