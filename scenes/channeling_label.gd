extends Node2D

signal channeling_finished
signal channeling_cancelled

@export var text: String = "CHANNELING"
@export var duration: float = 3.0
@export var autostart: bool = false

@onready var _bg_label: Label = $BGLabel
@onready var _clip_container: Control = $ClipContainer
@onready var _active_label: Label = $ClipContainer/ActiveLabel

var _tween: Tween
var _initial_width: float

func _ready() -> void:
	_bg_label.text = text
	_active_label.text = text

	# Resize containers to fit actual text size
	var label_size: Vector2 = _bg_label.get_minimum_size()
	_clip_container.size = label_size
	_active_label.size = label_size
	_initial_width = label_size.x

	if autostart:
		start()

func start() -> void:
	if _tween != null:
		return  # Already running

	_tween = create_tween()
	_tween.tween_property(_clip_container, "size:x", 0.0, duration)
	_tween.finished.connect(_on_channeling_complete)


func _on_channeling_complete() -> void:
	channeling_finished.emit()
	queue_free()


func cancel() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

	channeling_cancelled.emit()
	queue_free()
