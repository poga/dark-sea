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

func test_try_pickup_emits_pickup_tween_requested():
	# Create a parent to hold the item (try_pickup calls item.get_parent().remove_child)
	var parent := Node2D.new()
	add_child(parent)
	var item := Area2D.new()
	# Add child nodes required by base_item._ready() and _update_state_visuals()
	for state_name in ["PickupState", "ActiveState", "InventoryState"]:
		var state_node := Node2D.new()
		state_node.name = state_name
		var label := Label.new()
		label.name = "Label"
		state_node.add_child(label)
		item.add_child(state_node)
	item.set_script(load("res://scenes/item/base_item.gd"))
	item.inventory_icon = load("res://icon.svg")
	parent.add_child(item)
	item.global_position = Vector2(100, 200)

	GameManager.reset_inventory()
	watch_signals(GameManager)
	GameManager.try_pickup(item)

	assert_signal_emitted(GameManager, "pickup_tween_requested")
	parent.queue_free()
