extends Node2D

var _basic_float_label_scene: PackedScene = preload("res://scenes/components/NumberLabel/basic_float_label.tscn")

func show_damage(amount: float, pos: Vector2) -> void:
	var label: Label = _basic_float_label_scene.instantiate()
	label.text = str(int(amount))
	label.global_position = pos
	add_child(label)
