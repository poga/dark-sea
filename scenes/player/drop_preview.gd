extends Node2D

@export var radius: float = 12.0
@export var valid_color: Color = Color(0.2, 0.8, 0.2, 0.5)
@export var invalid_color: Color = Color(0.8, 0.2, 0.2, 0.5)

var is_valid: bool = true

func _draw() -> void:
	var color: Color = valid_color if is_valid else invalid_color
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color.lightened(0.3), 2.0)

func update_state(new_valid: bool) -> void:
	if is_valid != new_valid:
		is_valid = new_valid
		queue_redraw()
