extends "res://scenes/item/base_item.gd"

## Turret item: a placeable turret that attacks nearby monsters.
## Overrides use() to return PLACE, has_preview() to enable drop preview,
## and adds activate/deactivate lifecycle methods.

func has_preview() -> bool:
	return true

func use(_context: Dictionary) -> int:
	return UseResult.PLACE

func activate() -> void:
	current_state = State.TURRET
	_update_state_visuals()
	_update_turret_systems()

func deactivate() -> void:
	_monsters_in_range.clear()
	current_state = State.PICKUP
	_update_state_visuals()
	_update_turret_systems()
