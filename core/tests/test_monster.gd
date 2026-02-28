extends GutTest

var monster: Area2D

func before_each():
	monster = preload("res://scenes/monster/monster.tscn").instantiate()
	add_child_autofree(monster)

func test_initial_hp():
	assert_eq(monster.hp, 30.0)

func test_take_damage_reduces_hp():
	monster.take_damage(10.0)
	assert_eq(monster.hp, 20.0)

func test_take_damage_emits_died_at_zero():
	watch_signals(monster)
	monster.take_damage(30.0)
	assert_signal_emitted(monster, "died")

func test_take_damage_does_not_emit_died_above_zero():
	watch_signals(monster)
	monster.take_damage(10.0)
	assert_signal_not_emitted(monster, "died")

func test_drifts_left():
	var start_x: float = monster.global_position.x
	monster._physics_process(0.1)
	assert_lt(monster.global_position.x, start_x)

func test_despawn_x_is_exported():
	assert_eq(monster.despawn_x, -500.0)

func test_despawns_when_past_left_edge():
	monster.global_position.x = monster.despawn_x - 1.0
	monster._physics_process(0.01)
	assert_true(monster.is_queued_for_deletion())

func test_take_damage_emits_damage_taken():
	watch_signals(monster)
	monster.global_position = Vector2(100, 200)
	monster.take_damage(10.0)
	assert_signal_emitted(monster, "damage_taken")

func test_monster_type_defaults_to_default():
	assert_eq(monster.monster_type, "default")

func test_died_signal_includes_type_and_position():
	watch_signals(monster)
	monster.global_position = Vector2(100, 200)
	monster.take_damage(30.0)
	assert_signal_emitted_with_parameters(monster, "died", ["default", Vector2(100, 200)])
