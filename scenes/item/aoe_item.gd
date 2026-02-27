extends "res://scenes/item/turret_item.gd"

@export var explosion_radius: float = 80.0

func _attack(target: Area2D) -> void:
	for monster in _monsters_in_range:
		if is_instance_valid(monster):
			monster.take_damage(projectile_damage)
