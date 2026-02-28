extends Node2D

var _previous_gold: int = 0

func _ready() -> void:
	GameManager.resource_changed.connect(_on_resource_changed)

func _on_resource_changed(type: String, new_amount: int) -> void:
	if type != "gold":
		return
	var delta: int = new_amount - _previous_gold
	_previous_gold = new_amount
	$NumberLabel.add(delta)
