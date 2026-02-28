extends GutTest

var player: CharacterBody2D

func before_each():
	GameManager.reset_inventory()
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	GameManager.register_player(player)

func _make_item() -> Area2D:
	var item: Area2D = preload("res://scenes/item/turret_item.tscn").instantiate()
	add_child_autofree(item)
	return item

func _simulate_item_enters_range(item: Area2D) -> void:
	player._on_pickup_zone_area_entered(item)

# --- Facing direction ---

func test_default_facing_direction():
	assert_eq(player.facing_direction, Vector2.RIGHT)

func test_update_facing_normalizes_input():
	player.update_facing(Vector2(3, 4))
	assert_almost_eq(player.facing_direction, Vector2(0.6, 0.8), Vector2(0.001, 0.001))

func test_update_facing_preserves_direction_on_zero_input():
	player.update_facing(Vector2(1, 0))
	player.update_facing(Vector2.ZERO)
	assert_eq(player.facing_direction, Vector2.RIGHT)

# --- Drop position ---

func test_get_drop_position_uses_facing_direction():
	player.facing_direction = Vector2.RIGHT
	var expected: Vector2 = player.global_position + Vector2.RIGHT * player.drop_distance
	assert_eq(player.get_drop_position(), expected)

func test_get_drop_position_diagonal():
	var dir: Vector2 = Vector2(1, 1).normalized()
	player.facing_direction = dir
	var expected: Vector2 = player.global_position + dir * player.drop_distance
	assert_almost_eq(player.get_drop_position(), expected, Vector2(0.001, 0.001))

# --- Auto-pickup delegation ---

func test_pickup_zone_delegates_to_game_manager():
	var item: Area2D = _make_item()
	_simulate_item_enters_range(item)
	await get_tree().process_frame
	assert_eq(GameManager.inventory[0], item)

func test_pickup_zone_ignores_non_pickup_items():
	var item: Area2D = _make_item()
	item.activate()
	_simulate_item_enters_range(item)
	assert_null(GameManager.inventory[0])

# --- Slot switching delegation ---

func test_switch_to_slot_delegates_to_game_manager():
	player.switch_to_slot(3)
	assert_eq(GameManager.active_slot, 3)
