extends Node2D

const BasicFloatLabel = preload("res://scenes/NumberLabel/basic_float_label.tscn")

func _on_plus_one_pressed():
	$NumberLabel.add(1)
	$PopNumberLabel.add(1)


func _on_plus_hundred_pressed():
	$NumberLabel.add(100)
	$PopNumberLabel.add(100)


func _on_spawn_float_pressed():
	var label: Label = BasicFloatLabel.instantiate()
	label.text = str(randi_range(1, 99))
	label.position = $SpawnFloat.position + $SpawnFloat.size / 2
	add_child(label)
