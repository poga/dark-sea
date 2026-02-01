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
	_initial_width = _clip_container.size.x

	if autostart:
		start()

func start() -> void:
	pass  # TODO: Implement in Task 3
