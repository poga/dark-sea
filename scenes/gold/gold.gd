extends Area2D

@export var value: int = 1
@export var friction: float = 0.85
@export var stop_threshold: float = 5.0
@export var magnet_acceleration: float = 3000.0
@export var magnet_max_speed: float = 1200.0
@export var pulse_min_alpha: float = 0.7
@export var rise_height: float = 20.0
@export var rise_duration: float = 0.2
@export var rise_pause: float = 0.15

enum State { SPAWNING, IDLE, RISING, COLLECTING }

var current_state: State = State.IDLE
var _velocity: Vector2 = Vector2.ZERO
var _target_body: Node2D = null
var _pulse_tween: Tween = null
var _rise_tween: Tween = null

func _ready() -> void:
	add_to_group("gold")
	body_entered.connect(_on_body_entered)

func start_spawning(vel: Vector2) -> void:
	_velocity = vel
	current_state = State.SPAWNING

func _physics_process(delta: float) -> void:
	match current_state:
		State.SPAWNING:
			_process_spawning(delta)
		State.COLLECTING:
			_process_collecting(delta)

func _process_spawning(delta: float) -> void:
	_velocity *= pow(friction, delta * 60.0)
	global_position += _velocity * delta
	if _velocity.length() < stop_threshold:
		_enter_idle()

func _enter_idle() -> void:
	current_state = State.IDLE
	_velocity = Vector2.ZERO
	_start_pulse()
	# Check if player is already overlapping
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			_enter_rising(body)
			return

func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate:a", pulse_min_alpha, 0.6)
	_pulse_tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _on_body_entered(body: Node2D) -> void:
	if current_state == State.IDLE and body is CharacterBody2D:
		_enter_rising(body)

func _enter_rising(body: CharacterBody2D) -> void:
	current_state = State.RISING
	_target_body = body
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	modulate.a = 1.0
	_rise_tween = create_tween()
	_rise_tween.tween_property(self, "global_position:y", global_position.y - rise_height, rise_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_rise_tween.tween_interval(rise_pause)
	_rise_tween.tween_callback(_on_rise_complete)

func _on_rise_complete() -> void:
	if not is_instance_valid(_target_body):
		queue_free()
		return
	_start_collecting(_target_body)

func _start_collecting(body: CharacterBody2D) -> void:
	current_state = State.COLLECTING
	_target_body = body
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	modulate.a = 1.0

func _process_collecting(delta: float) -> void:
	if not is_instance_valid(_target_body):
		queue_free()
		return
	var desired: Vector2 = (_target_body.global_position - global_position).normalized() * magnet_max_speed
	_velocity = _velocity.move_toward(desired, magnet_acceleration * delta)
	global_position += _velocity * delta
	var dist: float = global_position.distance_to(_target_body.global_position)
	if dist < 10.0:
		GameManager.add_gold(value)
		queue_free()
