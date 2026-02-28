extends GutTest

var _pickup_scene: PackedScene = preload("res://scenes/pickup/resource_pickup.tscn")

func before_each() -> void:
	GameManager.resources = {}

func test_pickup_starts_in_idle_state():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	assert_eq(pickup.current_state, pickup.State.IDLE)

func test_start_spawning_sets_state():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(100, 0))
	assert_eq(pickup.current_state, pickup.State.SPAWNING)

func test_spawning_applies_friction():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(200, 0))
	var start_pos: Vector2 = pickup.global_position
	pickup._process_spawning(0.016)
	assert_ne(pickup.global_position, start_pos, "Pickup should have moved")

func test_spawning_transitions_to_idle_when_slow():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(1, 0))
	pickup._process_spawning(0.016)
	assert_eq(pickup.current_state, pickup.State.IDLE)

func test_idle_pickup_ignores_body_during_spawning():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.start_spawning(Vector2(200, 0))
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	pickup._on_body_entered(dummy)
	assert_eq(pickup.current_state, pickup.State.SPAWNING, "Should stay in SPAWNING")

func test_body_entered_during_idle_starts_rising():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	assert_eq(pickup.current_state, pickup.State.IDLE)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	pickup._on_body_entered(dummy)
	assert_eq(pickup.current_state, pickup.State.RISING)

func test_collecting_moves_toward_target():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	pickup.global_position = Vector2(100, 0)
	var target: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(target)
	target.global_position = Vector2.ZERO
	pickup._start_collecting(target)
	var start_dist: float = pickup.global_position.distance_to(target.global_position)
	pickup._process_collecting(0.1)
	var end_dist: float = pickup.global_position.distance_to(target.global_position)
	assert_lt(end_dist, start_dist, "Pickup should move closer to target")

func test_rising_ignores_additional_body_entered():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	var dummy1: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy1)
	pickup._on_body_entered(dummy1)
	assert_eq(pickup.current_state, pickup.State.RISING)
	var dummy2: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy2)
	pickup._on_body_entered(dummy2)
	assert_eq(pickup.current_state, pickup.State.RISING, "Should stay in RISING")

func test_rise_complete_transitions_to_collecting():
	var pickup: Area2D = _pickup_scene.instantiate()
	add_child_autofree(pickup)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	pickup._on_body_entered(dummy)
	assert_eq(pickup.current_state, pickup.State.RISING)
	pickup._on_rise_complete()
	assert_eq(pickup.current_state, pickup.State.COLLECTING)
