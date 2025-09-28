extends Node2D

@export var value: int = 0

var _scale_tween: Tween

signal value_updated(new_value: int)

func _ready():
	update_label()

func update_label():
	$ValueLabel.text = str(value)

func add(amount: int):
	# Update value directly
	value += amount
	update_label()

	# Create impact animation (1.5x scale for 500ms)
	_create_impact_animation()

	# Emit signal
	value_updated.emit(value)

func subtract(amount: int):
	add(-amount)

func _create_impact_animation():
	# Kill any existing scale animation
	if _scale_tween:
		_scale_tween.kill()

	_scale_tween = create_tween()
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.set_trans(Tween.TRANS_BACK)

	# Scale up to 1.5x then back to 1.0 over 500ms
	$ValueLabel.scale = Vector2(1.5, 1.5)
	_scale_tween.tween_property($ValueLabel, "scale", Vector2(1.0, 1.0), 0.5)