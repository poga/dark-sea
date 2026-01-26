extends Node2D

@export var value: int = 0

@export_group("Animation")
@export var impact_scale: float = 1.5  ## Base scale multiplier on value change
@export var scale_variation: float = 0.4  ## ±40% randomness on scale
@export var max_rotation_degrees: float = 20.0  ## Max rotation in either direction
@export var animation_duration: float = 0.15  ## How long the settle animation takes

var _tween: Tween

signal value_updated(new_value: int)

func _ready():
	update_label()

func update_label():
	$ValueLabel.text = str(value)

func add(amount: int):
	# Update value directly
	value += amount
	update_label()

	# Create impact animation
	_create_impact_animation()

	# Emit signal
	value_updated.emit(value)

func subtract(amount: int):
	add(-amount)

func _create_impact_animation():
	# Kill any existing animation
	if _tween:
		_tween.kill()

	# Calculate random scale with variation
	var scale_multiplier = impact_scale * randf_range(1.0 - scale_variation, 1.0 + scale_variation)

	# Calculate random rotation (either direction)
	var rotation_amount = randf_range(-max_rotation_degrees, max_rotation_degrees)

	# Instantly snap to peak state
	$ValueLabel.scale = Vector2(scale_multiplier, scale_multiplier)
	$ValueLabel.rotation_degrees = rotation_amount

	# Animate back to normal
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_parallel(true)
	_tween.tween_property($ValueLabel, "scale", Vector2(1.0, 1.0), animation_duration)
	_tween.tween_property($ValueLabel, "rotation_degrees", 0.0, animation_duration)
