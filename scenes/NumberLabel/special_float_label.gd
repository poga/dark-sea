extends Label

# Phase 1 - Impact
@export var phase1_duration: float = 0.3
@export var phase1_distance: float = 20.0
@export var scale_overshoot: float = 1.3
@export var scale_target: float = 1.2
@export var rotation_overshoot: float = 0.1  ## Max rotation in radians (randomized ±)

# Pause
@export var pause_duration: float = 0.1

# Phase 2 - Drift
@export var phase2_duration: float = 0.5
@export var phase2_distance: float = 40.0

func _ready():
	var start_pos: Vector2 = position

	# Single random factor controls both rotation and movement direction
	var random_factor: float = randf_range(-1.0, 1.0)
	var random_rotation: float = random_factor * rotation_overshoot
	var angle: float = deg_to_rad(-90.0 + random_factor * 10.0)
	var direction: Vector2 = Vector2(cos(angle), sin(angle))

	var tween: Tween = create_tween()

	# Phase 1: Impact (parallel)
	tween.set_parallel(true)
	tween.tween_property(self, "position", start_pos + direction * phase1_distance, phase1_duration) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "scale", Vector2.ONE * scale_overshoot, phase1_duration * 0.95) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", random_rotation, phase1_duration * 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", Vector2.ONE * scale_target, phase1_duration * 0.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_property(self, "rotation", 0.0, phase1_duration * 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Pause
	tween.set_parallel(false)
	tween.tween_interval(pause_duration)

	# Phase 2: Drift (parallel)
	tween.set_parallel(true)
	tween.tween_property(self, "position", start_pos + direction * (phase1_distance + phase2_distance), phase2_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, phase2_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.finished.connect(queue_free)
