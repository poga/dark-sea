extends Node

signal state_changed(new_state)
signal day_started
signal night_started
signal phase_changed(phase: Phase)

enum Phase { DAY, NIGHT }

var state: int = 0
var current_phase: Phase = Phase.DAY

@export var day_duration: float = 30.0
@export var night_duration: float = 30.0

var _phase_timer: Timer

func _ready() -> void:
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	_phase_timer.timeout.connect(_on_phase_timer_timeout)
	add_child(_phase_timer)

func increment_state():
	state += 1
	state_changed.emit(state)
	return state

func start_cycle() -> void:
	_phase_timer.stop()
	current_phase = Phase.DAY
	day_started.emit()
	phase_changed.emit(current_phase)
	_phase_timer.wait_time = day_duration
	_phase_timer.start()

func _on_phase_timer_timeout() -> void:
	if current_phase == Phase.DAY:
		current_phase = Phase.NIGHT
		night_started.emit()
		_phase_timer.wait_time = night_duration
	else:
		current_phase = Phase.DAY
		day_started.emit()
		_phase_timer.wait_time = day_duration
	phase_changed.emit(current_phase)
	_phase_timer.start()
