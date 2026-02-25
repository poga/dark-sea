extends Label

func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: GameManager.Phase) -> void:
	if phase == GameManager.Phase.DAY:
		text = "Day"
	else:
		text = "Night"
