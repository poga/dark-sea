extends Node2D

const BasicFloatLabel = preload("res://scenes/NumberLabel/basic_float_label.tscn")
const SpecialFloatLabel = preload("res://scenes/NumberLabel/special_float_label.tscn")

@export var idle_timeout: float = 1.0

@onready var basic_pos: Marker2D = $BasicLabelPosition
@onready var special_pos: Marker2D = $SpecialLabelPosition
@onready var pop_label: Node2D = $PopLabelPosition/PopNumberLabel

var idle_timer: float = 0.0
var is_active: bool = false

func _ready() -> void:
	pop_label.visible = false

func _process(delta: float) -> void:
	if is_active:
		idle_timer += delta
		if idle_timer >= idle_timeout:
			_hide_pop_label()

func show_basic(amount: int) -> void:
	_ensure_active()
	_spawn_label(BasicFloatLabel, basic_pos.global_position, amount)
	pop_label.add(amount)
	_reset_idle_timer()

func show_special(amount: int) -> void:
	_ensure_active()
	_spawn_label(SpecialFloatLabel, special_pos.global_position, amount)
	pop_label.add(amount)
	_reset_idle_timer()

func reset() -> void:
	_hide_pop_label()

func _ensure_active() -> void:
	if not is_active:
		is_active = true
		pop_label.value = 0
		pop_label.update_label()
		pop_label.visible = true

func _hide_pop_label() -> void:
	is_active = false
	pop_label.visible = false
	idle_timer = 0.0

func _reset_idle_timer() -> void:
	idle_timer = 0.0

func _spawn_label(scene: PackedScene, pos: Vector2, amount: int) -> void:
	var label: Label = scene.instantiate()
	label.text = str(amount)
	label.global_position = pos
	get_tree().root.add_child(label)
