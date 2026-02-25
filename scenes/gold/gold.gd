extends Area2D

@export var value: int = 1

func _ready() -> void:
	add_to_group("gold")
	body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node2D) -> void:
	GameManager.add_gold(value)
	queue_free()
