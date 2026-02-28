extends GutTest

var _gold_scene: PackedScene = preload("res://scenes/gold/gold.tscn")

func test_gold_starts_in_idle_state():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	assert_eq(gold.current_state, gold.State.IDLE)

func test_start_spawning_sets_state():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.start_spawning(Vector2(100, 0))
	assert_eq(gold.current_state, gold.State.SPAWNING)

func test_spawning_applies_friction():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.start_spawning(Vector2(200, 0))
	var start_pos: Vector2 = gold.global_position
	# Simulate one physics frame
	gold._process_spawning(0.016)
	assert_ne(gold.global_position, start_pos, "Gold should have moved")

func test_spawning_transitions_to_idle_when_slow():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.start_spawning(Vector2(1, 0))  # Very slow, below threshold
	gold._process_spawning(0.016)
	assert_eq(gold.current_state, gold.State.IDLE)

func test_idle_gold_ignores_body_during_spawning():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.start_spawning(Vector2(200, 0))
	# Simulate body entering during SPAWNING
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	gold._on_body_entered(dummy)
	assert_eq(gold.current_state, gold.State.SPAWNING, "Should stay in SPAWNING")

func test_body_entered_during_idle_starts_rising():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	assert_eq(gold.current_state, gold.State.IDLE)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	gold._on_body_entered(dummy)
	assert_eq(gold.current_state, gold.State.RISING)

func test_collecting_moves_toward_target():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	gold.global_position = Vector2(100, 0)
	var target: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(target)
	target.global_position = Vector2.ZERO
	gold._start_collecting(target)
	var start_dist: float = gold.global_position.distance_to(target.global_position)
	gold._process_collecting(0.1)
	var end_dist: float = gold.global_position.distance_to(target.global_position)
	assert_lt(end_dist, start_dist, "Gold should move closer to target")

func test_rising_ignores_additional_body_entered():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	var dummy1: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy1)
	gold._on_body_entered(dummy1)
	assert_eq(gold.current_state, gold.State.RISING)
	# Second body should be ignored
	var dummy2: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy2)
	gold._on_body_entered(dummy2)
	assert_eq(gold.current_state, gold.State.RISING, "Should stay in RISING")

func test_rise_complete_transitions_to_collecting():
	var gold: Area2D = _gold_scene.instantiate()
	add_child_autofree(gold)
	var dummy: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(dummy)
	gold._on_body_entered(dummy)
	assert_eq(gold.current_state, gold.State.RISING)
	# Simulate tween completion
	gold._on_rise_complete()
	assert_eq(gold.current_state, gold.State.COLLECTING)
