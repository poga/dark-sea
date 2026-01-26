extends Node2D

@export var value: int = 0

@export_group("Animation")
@export var min_scale: float = 1.5  ## Minimum scale on pop
@export var max_scale: float = 2.0  ## Maximum scale on pop
@export var max_rotation_degrees: float = 20.0  ## Max rotation in either direction
@export var pop_duration: float = 0.1  ## How long the pop is visible before snapping back

signal value_updated(new_value: int)

func _ready():
	update_label()

func update_label():
	$ValueLabel.text = str(value)
	# Update pivot to center for rotation
	$ValueLabel.pivot_offset = $ValueLabel.size * 0.5

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
	# Calculate random scale
	var scale_multiplier = randf_range(min_scale, max_scale)

	# Calculate random rotation (either direction)
	var rotation_amount = randf_range(-max_rotation_degrees, max_rotation_degrees)

	# Instantly snap to peak state
	$ValueLabel.scale = Vector2(scale_multiplier, scale_multiplier)
	$ValueLabel.rotation_degrees = rotation_amount

	# Snap back after brief delay
	get_tree().create_timer(pop_duration).timeout.connect(_snap_back)

func _snap_back():
	$ValueLabel.scale = Vector2.ONE
	$ValueLabel.rotation_degrees = 0.0
