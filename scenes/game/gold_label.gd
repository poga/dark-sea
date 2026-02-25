extends Node2D

var _previous_gold: int = 0

func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)

func _on_gold_changed(new_amount: int) -> void:
	var delta: int = new_amount - _previous_gold
	_previous_gold = new_amount
	$NumberLabel.add(delta)
