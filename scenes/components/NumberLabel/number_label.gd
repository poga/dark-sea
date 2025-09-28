extends Node2D

@export var value: int = 0

var _ui_value: int = 0  # Value shown in UI (lags behind real value)
var _delta_accumulation: int = 0  # Accumulated delta changes
var _damping_timer: float = 0.0
var _damping_delay: float = 1.0
var _current_tween: Tween

signal delta_value_update_started(current_value: int, delta: int)
signal delta_value_update_finished(final_value: int)
signal value_update_finished(final_value: int, total_delta: int)

func _ready():
	_ui_value = value
	update_ui_label()

func _process(delta):
	if _delta_accumulation == 0:
		return

	_damping_timer += delta

	# Start fade animation after damping delay
	if _damping_timer >= _damping_delay:
		_start_fade_animation()

func _start_fade_animation():
	if _current_tween:
		return  # Animation already running

	delta_value_update_finished.emit(value)

	# Start fade animation
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_trans(Tween.TRANS_QUAD)

	var original_position = $DeltaLabel.position
	_current_tween.tween_property($DeltaLabel, "modulate:a", 0.0, 0.5)
	_current_tween.tween_property($DeltaLabel, "position:x", original_position.x - 20, 0.5)

	# Update UI value halfway through fade (0.25 seconds)
	_current_tween.tween_callback(_update_ui_value_with_flash).set_delay(0.25)

	await _current_tween.finished

	# Clean up
	$DeltaLabel.position = original_position
	$DeltaLabel.modulate.a = 1.0
	$DeltaLabel.text = ""
	$DeltaLabel.visible = false

	value_update_finished.emit(value, _delta_accumulation)
	_delta_accumulation = 0
	_damping_timer = 0.0
	_current_tween = null

func _update_ui_value_with_flash():
	# Update UI value to match real value
	_ui_value = value
	update_ui_label()

	# Flash effect
	var flash_tween = create_tween()
	$ValueLabel.modulate = Color.YELLOW
	flash_tween.tween_property($ValueLabel, "modulate", Color.WHITE, 0.3)

func update_ui_label():
	$ValueLabel.text = str(_ui_value)

func add(amount: int):
	# 1. Update underlying value immediately
	value += amount

	# 2. Accumulate delta and show delta label
	_delta_accumulation += amount

	# Kill any existing tween and reset state
	if _current_tween:
		_current_tween.kill()
		_current_tween = null

	# Reset delta label to initial state
	$DeltaLabel.modulate.a = 1.0
	$DeltaLabel.position = Vector2(88, 0)

	# Show delta label immediately
	var prefix = "+" if _delta_accumulation > 0 else ""
	$DeltaLabel.text = prefix + str(_delta_accumulation)
	$DeltaLabel.visible = true

	# Reset damping timer
	_damping_timer = 0.0

	delta_value_update_started.emit(_ui_value, amount)

func subtract(amount: int):
	add(-amount)
