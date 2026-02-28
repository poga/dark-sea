extends GutTest

# Barebones GameManager singleton test example

func before_each() -> void:
	GameManager.gold = 0
	GameManager.resources = {}
	GameManager.selected_character = ""
	GameManager.characters = {}
	GameManager._unlocked_overrides = []

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

	assert_signal_emitted_with_parameters(
		GameManager, "pickup_tween_requested",
		[load("res://icon.svg"), Vector2(100, 200), 0]
	)
	GameManager.reset_inventory()
	parent.queue_free()

func test_add_resource_stores_value():
	GameManager.add_resource("bones", 5)
	assert_eq(GameManager.get_resource("bones"), 5)

func test_add_resource_accumulates():
	GameManager.add_resource("bones", 2)
	GameManager.add_resource("bones", 3)
	assert_eq(GameManager.get_resource("bones"), 5)

func test_add_resource_emits_resource_changed():
	watch_signals(GameManager)
	GameManager.add_resource("bones", 3)
	assert_signal_emitted_with_parameters(GameManager, "resource_changed", ["bones", 3])

func test_get_resource_returns_zero_for_unknown():
	assert_eq(GameManager.get_resource("unknown_type"), 0)

func test_add_gold_uses_resource_system():
	GameManager.add_gold(5)
	assert_eq(GameManager.get_resource("gold"), 5)

func test_add_gold_still_emits_gold_changed():
	watch_signals(GameManager)
	GameManager.add_gold(3)
	assert_signal_emitted_with_parameters(GameManager, "gold_changed", [3])

# --- Character loading and selection ---

func test_load_characters_populates_characters_dict():
	GameManager.load_characters()
	assert_gt(GameManager.characters.size(), 0, "Should load at least one character")

func test_load_characters_has_default():
	GameManager.load_characters()
	assert_true(GameManager.characters.has("default"), "Should have default character")

func test_load_characters_default_has_name():
	GameManager.load_characters()
	var char_data: Dictionary = GameManager.characters["default"]
	assert_true(char_data.has("name"), "Default character should have a name field")

func test_set_character_stores_selection():
	GameManager.load_characters()
	GameManager.set_character("default")
	assert_eq(GameManager.selected_character, "default")

func test_get_character_returns_data():
	GameManager.load_characters()
	GameManager.set_character("default")
	var data: Dictionary = GameManager.get_character()
	assert_true(data.has("name"), "Character data should have a name field")

func test_set_character_emits_signal():
	GameManager.load_characters()
	watch_signals(GameManager)
	GameManager.set_character("default")
	assert_signal_emitted_with_parameters(GameManager, "character_selected", ["default"])

func test_get_character_returns_empty_when_none_selected():
	GameManager.selected_character = ""
	var data: Dictionary = GameManager.get_character()
	assert_eq(data.size(), 0)

# --- Character unlock persistence ---

func test_default_character_is_unlocked():
	GameManager.load_characters()
	assert_true(GameManager.is_character_unlocked("default"))

func test_locked_character_is_not_unlocked():
	GameManager.characters["locked_test"] = {"name": "Test", "locked": true}
	assert_false(GameManager.is_character_unlocked("locked_test"))

func test_unlock_character_makes_it_unlocked():
	GameManager.characters["locked_test"] = {"name": "Test", "locked": true}
	GameManager.unlock_character("locked_test")
	assert_true(GameManager.is_character_unlocked("locked_test"))

func test_unlock_character_emits_signal():
	GameManager.characters["locked_test"] = {"name": "Test", "locked": true}
	watch_signals(GameManager)
	GameManager.unlock_character("locked_test")
	assert_signal_emitted_with_parameters(GameManager, "character_unlocked", ["locked_test"])

func test_get_unlocked_characters_returns_unlocked_only():
	GameManager.load_characters()
	var unlocked: Array = GameManager.get_unlocked_characters()
	for id: String in unlocked:
		assert_true(GameManager.is_character_unlocked(id))

# --- Character loadout ---

func test_apply_character_loadout_sets_resources():
	GameManager.load_characters()
	GameManager.characters["test_char"] = {
		"name": "Test",
		"starting_items": [],
		"starting_resources": {"gold": 10, "bones": 5},
		"locked": false,
	}
	GameManager.set_character("test_char")
	GameManager.apply_character_loadout()
	assert_eq(GameManager.get_resource("gold"), 10)
	assert_eq(GameManager.get_resource("bones"), 5)

func test_apply_character_loadout_adds_starting_items_to_inventory():
	GameManager.load_characters()
	GameManager.set_character("default")
	GameManager.apply_character_loadout()
	assert_ne(GameManager.inventory[0], null, "Starting item should be in slot 0")

func test_apply_character_loadout_does_nothing_when_no_character():
	GameManager.selected_character = ""
	GameManager.apply_character_loadout()
	assert_eq(GameManager.get_resource("gold"), 0)

func test_reset_for_new_game_preserves_player_reference():
	var player := CharacterBody2D.new()
	add_child(player)
	GameManager.register_player(player)
	GameManager.reset_for_new_game()
	assert_eq(GameManager._player, player, "Player reference should survive reset")
	player.queue_free()
