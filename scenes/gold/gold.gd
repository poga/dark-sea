extends Area2D

@export var value: int = 1
@export var friction: float = 0.85
@export var stop_threshold: float = 5.0
@export var magnet_acceleration: float = 1500.0
@export var magnet_max_speed: float = 600.0
@export var pulse_min_alpha: float = 0.7

enum State { SPAWNING, IDLE, COLLECTING }

var current_state: State = State.IDLE
var spawn_velocity: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _target_body: Node2D = null
var _pulse_tween: Tween = null

func _ready() -> void:
	add_to_group("gold")
	body_entered.connect(_on_body_entered)

func start_spawning(vel: Vector2) -> void:
	spawn_velocity = vel
	_velocity = vel
	current_state = State.SPAWNING

func _physics_process(delta: float) -> void:
	match current_state:
		State.SPAWNING:
			_process_spawning(delta)
		State.COLLECTING:
			_process_collecting(delta)

func _process_spawning(_delta: float) -> void:
	_velocity *= friction
	global_position += _velocity
	if _velocity.length() < stop_threshold:
		_enter_idle()

func _enter_idle() -> void:
	current_state = State.IDLE
	_velocity = Vector2.ZERO
	_start_pulse()
	# Check if player is already overlapping
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			_start_collecting(body)
			return

func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate:a", pulse_min_alpha, 0.6)
	_pulse_tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _on_body_entered(body: Node2D) -> void:
	if current_state == State.IDLE:
		_start_collecting(body)

func _start_collecting(body: Node2D) -> void:
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
	var dir: Vector2 = (_target_body.global_position - global_position).normalized()
	_velocity += dir * magnet_acceleration * delta
	if _velocity.length() > magnet_max_speed:
		_velocity = _velocity.normalized() * magnet_max_speed
	global_position += _velocity * delta
	# Scale down as we approach
	var dist: float = global_position.distance_to(_target_body.global_position)
	scale = Vector2.ONE * clampf(dist / 50.0, 0.3, 1.0)
	if dist < 10.0:
		GameManager.add_gold(value)
		queue_free()
