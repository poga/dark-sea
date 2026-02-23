# Turret Behavior Customization Design

## Overview

Enable designers to create different turret types by duplicating the item scene and writing a custom script that extends a base class. Parameter-only variants just tweak `@export` values. Fundamentally different behaviors override virtual methods.

## Architecture

`item.gd` becomes `base_item.gd` - the base class for all items. It keeps all pickup/drop/state/zone logic. Attack-related methods become virtual (overridable):

```gdscript
# Virtual methods - override in custom items
func _find_target() -> Area2D:
    # Default: closest monster. Override for custom targeting.

func _attack(target: Area2D) -> void:
    # Default: shoot projectile. Override for custom attacks.

func _on_turret_activated() -> void:
    # Called when item enters turret state. Override for setup.

func _on_turret_deactivated() -> void:
    # Called when item is picked up from turret state. Override for cleanup.
```

Inherited `@export` vars: `attack_range`, `attack_rate`, `projectile_speed`, `projectile_damage`. Custom scripts add their own exports on top.

`_on_shoot_timer_timeout()` calls `_attack(_find_target())` so overriding either method works independently.

## Designer Workflow

1. Duplicate `item.tscn` → e.g., `aoe_cannon.tscn`
2. Create `aoe_cannon.gd` extending `base_item.gd`, override attack methods
3. Assign new script to root node of duplicated scene
4. Tweak inherited + custom exports in Inspector
5. Customize TurretState visuals (sprite, label)
6. Add scene to game - works with existing pickup/drop/zone system automatically

## Changes to Current Code

1. Rename `item.gd` → `base_item.gd`
2. Update `item.tscn` to reference `base_item.gd`
3. Rename `_shoot_at()` → `_attack()` (virtual method)
4. `_find_target()` stays as-is (already isolated)
5. Add `_on_turret_activated()` hook, called from `drop()`
6. Add `_on_turret_deactivated()` hook, called from `pick_up()`
7. `_on_shoot_timer_timeout` calls `_attack()` instead of `_shoot_at()`
8. Update all tests to reference renamed script

## Example: AOE Cannon

```gdscript
extends "res://scenes/item/base_item.gd"

@export var explosion_radius: float = 80.0

func _attack(target: Area2D) -> void:
    for monster in _monsters_in_range:
        if is_instance_valid(monster):
            monster.take_damage(projectile_damage)
```
