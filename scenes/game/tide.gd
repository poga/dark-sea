extends ColorRect

signal tide_position_changed(left_edge_x: float)
signal tide_ebbed
signal tide_risen

@export var ebb_duration: float = 5.0
@export var rise_duration: float = 5.0
@export var ebb_ratio: float = 0.8

var _full_left: float
var _width: float
var _tween: Tween

func _ready() -> void:
	_full_left = offset_left
	_width = offset_right - offset_left
	GameManager.day_started.connect(_start_ebb)
	GameManager.night_started.connect(_start_rise)

func _start_ebb() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var target_left: float = _full_left + _width * ebb_ratio
	_tween = create_tween()
	_tween.tween_method(_update_tide_position, offset_left, target_left, ebb_duration)
	_tween.tween_callback(func(): tide_ebbed.emit())

func _start_rise() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_update_tide_position, offset_left, _full_left, rise_duration)
	_tween.tween_callback(func(): tide_risen.emit())

func _update_tide_position(left_x: float) -> void:
	offset_left = left_x
	tide_position_changed.emit(left_x)
