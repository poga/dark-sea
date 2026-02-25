extends Node2D

func _ready() -> void:
	GameManager.start_cycle.call_deferred()
