extends Node2D

@export var value: int = 0

@export_group("Animation")
@export var impact_scale: float = 1.5  ## Scale multiplier on value change
@export var animation_duration: float = 0.5  ## How long the scale animation takes

var _scale_tween: Tween

signal value_updated(new_value: int)

func _ready():
	update_label()

func update_label():
	$ValueLabel.text = str(value)
	# Recalculate pivot_offset to center of label based on actual text size
	var label_size = $ValueLabel.get_theme_default_font().get_string_size(
		$ValueLabel.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		$ValueLabel.get_theme_default_font_size()
	)
	$ValueLabel.pivot_offset = label_size * 0.5

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

	# Scale up then back to 1.0
	$ValueLabel.scale = Vector2(impact_scale, impact_scale)
	_scale_tween.tween_property($ValueLabel, "scale", Vector2(1.0, 1.0), animation_duration)