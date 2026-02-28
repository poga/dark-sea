# Damage Numbers Fix Design

## Problem

Damage numbers disappear on killing blows because `BasicFloatLabel` is added as a child of the monster. When the monster dies (`queue_free()`), the label is destroyed before it can animate. This is most visible with the hammer (100 damage vs 30 HP = always a one-hit kill).

## Solution

Move damage number display responsibility out of the monster and into a dedicated `DamageNumbers` node in the game scene, wired via signals.

## Architecture

### New: `scenes/game/damage_numbers.gd` + Node2D in `main.tscn`

- Preloads `BasicFloatLabel` scene
- `show_damage(amount: float, pos: Vector2)` — instantiates label, sets text and global_position, adds as child

### Changes to `monster.gd`

- Add signal: `damage_taken(amount: float, pos: Vector2)`
- In `take_damage()`: emit `damage_taken` with amount and `global_position`
- Remove `_basic_float_label_scene` preload and `_show_damage_number()` method

### Changes to `monster_spawner.gd`

- Get reference to `DamageNumbers` node (sibling in scene tree)
- When spawning a monster, connect `monster.damage_taken` to `DamageNumbers.show_damage`

### Changes to `main.tscn`

- Add `DamageNumbers` (Node2D) node with `damage_numbers.gd` script

## Signal Flow

```
Monster.take_damage(amount)
  → emits damage_taken(amount, global_position)
  → (connected by spawner) → DamageNumbers.show_damage(amount, pos)
  → spawns BasicFloatLabel at pos (child of DamageNumbers, NOT monster)
  → label animates and self-frees after 0.8s
```

Labels survive monster death because they live under `DamageNumbers`, not the monster.
