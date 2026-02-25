extends Node2D

func _ready() -> void:
	GameManager.start_cycle.call_deferred()
	%DebugSkipPhase.pressed.connect(GameManager.skip_to_next_phase)
