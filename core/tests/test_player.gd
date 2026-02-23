extends GutTest

var player: CharacterBody2D
var item_scene: PackedScene = preload("res://scenes/item/item.tscn")

func before_each():
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)

func _make_item(pos: Vector2) -> Area2D:
	var item: Area2D = item_scene.instantiate()
	add_child_autofree(item)
	item.global_position = pos
	return item

func test_no_held_item_initially():
	assert_null(player.held_item)

func test_get_nearest_item_returns_null_when_empty():
	assert_null(player.get_nearest_item())

func test_get_nearest_item_returns_closest():
	var far_item: Area2D = _make_item(Vector2(200, 0))
	var near_item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(far_item)
	player._items_in_range.append(near_item)
	assert_eq(player.get_nearest_item(), near_item)

func test_pick_up_sets_held_item():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(item)
	player.pick_up_nearest_item()
	assert_eq(player.held_item, item)

func test_pick_up_emits_signal():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(item)
	watch_signals(player)
	player.pick_up_nearest_item()
	assert_signal_emitted(player, "item_picked_up")

func test_pick_up_reparents_to_hold_position():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(item)
	player.pick_up_nearest_item()
	assert_eq(item.get_parent(), player.get_node("HoldPosition"))

func test_pick_up_removes_from_items_in_range():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(item)
	player.pick_up_nearest_item()
	assert_false(player._items_in_range.has(item))

func test_drop_clears_held_item():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(item)
	player.pick_up_nearest_item()
	player.drop_item()
	assert_null(player.held_item)

func test_drop_emits_signal():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(item)
	player.pick_up_nearest_item()
	watch_signals(player)
	player.drop_item()
	assert_signal_emitted(player, "item_dropped")

func test_drop_reparents_to_world():
	var item: Area2D = _make_item(Vector2(30, 0))
	player._items_in_range.append(item)
	player.pick_up_nearest_item()
	player.drop_item()
	assert_eq(item.get_parent(), player.get_parent())

func test_pick_up_does_nothing_when_no_items():
	player.pick_up_nearest_item()
	assert_null(player.held_item)
