extends Node2D

const BasicFloatLabel = preload("res://scenes/NumberLabel/basic_float_label.tscn")
const SpecialFloatLabel = preload("res://scenes/NumberLabel/special_float_label.tscn")
const ChannelingLabel = preload("res://scenes/channeling_label.tscn")

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


func _on_spawn_special_pressed():
	var label: Label = SpecialFloatLabel.instantiate()
	label.text = str(randi_range(100, 999))
	label.position = $SpawnSpecial.position + $SpawnSpecial.size / 2
	add_child(label)


func _on_spawn_channel_pressed():
	var channel: Node2D = ChannelingLabel.instantiate()
	channel.text = $ChannelTextInput.text
	channel.position = Vector2(270, 350)
	add_child(channel)
	channel.start()
