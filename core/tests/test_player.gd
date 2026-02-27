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

func test_snap_to_cardinal_right():
	assert_eq(player.snap_to_cardinal(Vector2(1, 0.3)), Vector2.RIGHT)

func test_snap_to_cardinal_left():
	assert_eq(player.snap_to_cardinal(Vector2(-1, 0.3)), Vector2.LEFT)

func test_snap_to_cardinal_down():
	assert_eq(player.snap_to_cardinal(Vector2(0.3, 1)), Vector2.DOWN)

func test_snap_to_cardinal_up():
	assert_eq(player.snap_to_cardinal(Vector2(0.3, -1)), Vector2.UP)

func test_snap_diagonal_prefers_horizontal():
	assert_eq(player.snap_to_cardinal(Vector2(1, 1)), Vector2.RIGHT)

# --- Drop position ---

func test_get_drop_position_right():
	player.facing_direction = Vector2.RIGHT
	var expected: Vector2 = player.global_position + Vector2.RIGHT * player.drop_distance
	assert_eq(player.get_drop_position(), expected)

func test_get_drop_position_left():
	player.facing_direction = Vector2.LEFT
	var expected: Vector2 = player.global_position + Vector2.LEFT * player.drop_distance
	assert_eq(player.get_drop_position(), expected)

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
