extends Label

func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	text = "Gold: 0"

func _on_gold_changed(new_amount: int) -> void:
	text = "Gold: " + str(new_amount)
