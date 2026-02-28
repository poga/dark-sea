# Character System Design

## Overview

Data-driven character system where each character combines a sprite, starting items, default resources, and gameplay stats. Characters are unlockable and selected before each game via a character select screen.

## Character Data

Characters defined in `data/characters.json`:

```json
{
  "fisher": {
    "name": "Fisher",
    "sprite": "res://assets/characters/fisher.png",
    "stats": {
      "speed": 200.0,
      "pickup_radius": 50.0
    },
    "starting_items": ["res://scenes/item/hammer_item.tscn"],
    "starting_resources": {
      "gold": 10
    },
    "locked": true
  }
}
```

- `stats` maps to player `@export` vars (speed, pickup_radius, etc.)
- `starting_items` are scene paths loaded into inventory slots at game start
- `starting_resources` applied via `GameManager.add_resource()`
- `locked` is the default lock state, overridden by save data

## Game Flow

```
main_menu.tscn -> [Play] -> character_select.tscn -> [Select] -> main.tscn
```

1. `project.godot` run scene changed to `main_menu.tscn`
2. "Play" button transitions to `character_select.tscn`
3. Character select shows VBoxContainer list: sprite, name, stats, starting items. Locked characters grayed out.
4. Player selects unlocked character -> `GameManager.set_character(id)`
5. Transition to `main.tscn` -> game starts with character applied

## New Scenes

```
scenes/menu/
  main_menu.tscn / main_menu.gd    # Title screen with "Play" button
  character_select.tscn / .gd       # Character list, select & start
```

## GameManager Changes

New properties:
- `characters: Dictionary` - loaded character definitions
- `selected_character: String` - current character ID

New methods:
- `load_characters()` - reads `data/characters.json`
- `set_character(id: String)` - stores selection
- `get_character() -> Dictionary` - returns current character data
- `unlock_character(id: String)` - unlocks and persists
- `is_character_unlocked(id: String) -> bool`
- `load_unlocks() -> Array[String]` - reads save file
- `save_unlock(id: String)` - writes save file

New signals:
- `character_selected(id: String)`
- `character_unlocked(id: String)`

## Player Scene Changes

On `_ready()`:
- Read character data from `GameManager.get_character()`
- Apply stats: `speed`, `pickup_radius`
- Swap sprite texture from character's `sprite` path
- GameManager populates starting inventory and resources

## Unlock Persistence

Save file at `user://save_data.json`:

```json
{
  "unlocked_characters": ["fisher", "knight"]
}
```

- On first run with no save file, characters with `"locked": false` are available
- At least one character must have `"locked": false` (starter character)
- `unlock_character()` adds to list and writes JSON
- Unlock trigger logic left open for future implementation
