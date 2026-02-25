extends GutTest

# Barebones GameManager singleton test example

func before_each() -> void:
	GameManager.gold = 0

func test_add_gold_increases_gold():
	GameManager.add_gold(5)
	assert_eq(GameManager.gold, 5)

func test_add_gold_emits_gold_changed():
	watch_signals(GameManager)
	GameManager.add_gold(3)
	assert_signal_emitted_with_parameters(GameManager, "gold_changed", [3])

func test_add_gold_accumulates():
	GameManager.add_gold(2)
	GameManager.add_gold(3)
	assert_eq(GameManager.gold, 5)

func test_increment_state():
	var initial_state = GameManager.state
	var result = GameManager.increment_state()

	assert_eq(GameManager.state, initial_state + 1, "State should increase by 1")
	assert_eq(result, initial_state + 1, "Function should return new state value")

func test_increment_state_multiple_times():
	var initial_state = GameManager.state

	GameManager.increment_state()
	GameManager.increment_state()
	GameManager.increment_state()

	assert_eq(GameManager.state, initial_state + 3, "State should increase by 3 after three increments")

func test_state_changed_signal():
	watch_signals(GameManager)

	GameManager.increment_state()

	assert_signal_emitted(GameManager, "state_changed", "state_changed signal should be emitted")

func test_start_cycle_begins_with_day():
	GameManager.start_cycle()
	assert_eq(GameManager.current_phase, GameManager.Phase.DAY)

func test_start_cycle_emits_day_started():
	watch_signals(GameManager)
	GameManager.start_cycle()
	assert_signal_emitted(GameManager, "day_started")

func test_start_cycle_emits_phase_changed_with_day():
	watch_signals(GameManager)
	GameManager.start_cycle()
	assert_signal_emitted_with_parameters(GameManager, "phase_changed", [GameManager.Phase.DAY])

func test_phase_timer_timeout_transitions_to_night():
	GameManager.start_cycle()
	watch_signals(GameManager)
	GameManager._on_phase_timer_timeout()
	assert_eq(GameManager.current_phase, GameManager.Phase.NIGHT)
	assert_signal_emitted(GameManager, "night_started")
	assert_signal_emitted_with_parameters(GameManager, "phase_changed", [GameManager.Phase.NIGHT])

func test_skip_to_next_phase_transitions_from_day_to_night():
	GameManager.start_cycle()
	watch_signals(GameManager)
	GameManager.skip_to_next_phase()
	assert_eq(GameManager.current_phase, GameManager.Phase.NIGHT)
	assert_signal_emitted(GameManager, "night_started")

func test_skip_to_next_phase_transitions_from_night_to_day():
	GameManager.start_cycle()
	GameManager._on_phase_timer_timeout()  # go to night
	watch_signals(GameManager)
	GameManager.skip_to_next_phase()
	assert_eq(GameManager.current_phase, GameManager.Phase.DAY)
	assert_signal_emitted(GameManager, "day_started")
