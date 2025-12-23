extends Node2D

func _on_plus_one_pressed():
	$NumberLabel.add(1)
	$PopNumberLabel.add(1)


func _on_plus_hundred_pressed():
	$NumberLabel.add(100)
	$PopNumberLabel.add(100)
