extends Area2D

signal died

@export var hp: float = 30.0
@export var speed: float = 50.0
@export var despawn_x: float = -500.0

var _basic_float_label_scene: PackedScene = preload("res://scenes/components/NumberLabel/basic_float_label.tscn")

func _physics_process(delta: float) -> void:
	global_position.x -= speed * delta
	if global_position.x < despawn_x:
		queue_free()

func take_damage(amount: float) -> void:
	hp -= amount
	_show_damage_number(amount)
	if hp <= 0:
		died.emit()
		queue_free()

func _show_damage_number(amount: float) -> void:
	var label: Label = _basic_float_label_scene.instantiate()
	label.text = str(int(amount))
	add_child(label)
