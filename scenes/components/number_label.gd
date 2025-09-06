extends Node2D

@export var value: int = 0
@export var UPDATE_INTERVAL: float = 0.05

var _pending_change: int = 0
var _accumulated_change: int = 0
var _is_animating: bool = false
var _time_since_last_update: float = 0.0
var _max_step: int = 10

signal value_update_started(current_value: int, delta: int)
signal value_update_finished(final_value: int)

func _ready():
	update_label()

	add(-999999)

func _process(delta):
	if not _is_animating or _pending_change == 0:
		return

	_time_since_last_update += delta

	if _time_since_last_update < UPDATE_INTERVAL:
		return

	_time_since_last_update = 0.0
	_update_step()

func _update_step():
	var step = min(abs(_max_step), abs(_pending_change))
	step *= sign(_pending_change)

	_accumulated_change += step
	_pending_change -= step

	var prefix = "+" if _accumulated_change > 0 else ""
	$DeltaLabel.text = prefix + str(_accumulated_change)
	$DeltaLabel.visible = true

	if _pending_change == 0:
		await get_tree().create_timer(0.5).timeout
		value += _accumulated_change
		update_label()
		$DeltaLabel.text = ""
		$DeltaLabel.visible = false
		_accumulated_change = 0
		_is_animating = false
		_time_since_last_update = 0.0
		value_update_finished.emit(value)

func update_label():
	$ValueLabel.text = str(value)

func add(amount: int):
	_max_step = (abs(amount) / 10) + 1
	_max_step *= sign(amount)

	if _is_animating:
		_pending_change += amount
	else:
		_pending_change = amount
		_accumulated_change = 0
		_is_animating = true

	value_update_started.emit(value, amount)

func subtract(amount: int):
	add(-amount)
