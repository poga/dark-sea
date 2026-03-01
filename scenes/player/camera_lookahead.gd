extends Camera2D

@export var lookahead_distance: float = 60.0
@export var lookahead_smoothing: float = 3.0

func _process(delta: float) -> void:
	var player: CharacterBody2D = get_parent() as CharacterBody2D
	if not player:
		return
	var target_offset: Vector2 = player.facing_direction * lookahead_distance
	offset = offset.lerp(target_offset, lookahead_smoothing * delta)
