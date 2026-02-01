extends Label

@export var float_distance: float = 80.0  ## How far the label floats
@export var float_duration: float = 0.8  ## Animation duration

func _ready():
	# Random angle: straight up (-90°) with ±10° deviation
	var angle_degrees: float = -90.0 + randf_range(-10.0, 10.0)
	var angle_radians: float = deg_to_rad(angle_degrees)
	var direction: Vector2 = Vector2(cos(angle_radians), sin(angle_radians))
	var target_offset: Vector2 = direction * float_distance

	# Store starting position
	var start_pos: Vector2 = position

	# Create tween
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# Position: fast start, subtle deceleration
	tween.tween_property(self, "position", start_pos + target_offset, float_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Fade: stays visible, then rapidly fades after halfway
	tween.tween_property(self, "modulate:a", 0.0, float_duration) \
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)

	tween.finished.connect(queue_free)
