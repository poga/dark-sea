extends GutTest

var player: CharacterBody2D
var item_scene: PackedScene = preload("res://scenes/item/item.tscn")
const ZoneScript = preload("res://scenes/zones/zone.gd")

func before_each():
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)

func _make_item(pos: Vector2) -> Area2D:
	var item: Area2D = item_scene.instantiate()
	add_child_autofree(item)
	item.global_position = pos
	return item

func _pick_up_item(item: Area2D) -> void:
	player._items_in_range.append(item)
	player.pick_up_nearest_item()

func test_current_zone_initially_null():
	assert_null(player.current_zone)

func test_can_drop_returns_false_when_no_zone():
	assert_false(player.can_drop())

func test_can_drop_returns_true_in_tower_zone():
	player.current_zone = ZoneScript.ZoneType.TOWER
	assert_true(player.can_drop())

func test_can_drop_returns_true_in_beach_zone():
	player.current_zone = ZoneScript.ZoneType.BEACH
	assert_true(player.can_drop())

func test_can_drop_returns_false_in_sea_zone():
	player.current_zone = ZoneScript.ZoneType.SEA
	assert_false(player.can_drop())

func test_drop_in_tower_zone_sets_turret_state():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	player.current_zone = ZoneScript.ZoneType.TOWER
	player.drop_item()
	assert_eq(item.current_state, item.State.TURRET)

func test_drop_in_beach_zone_keeps_pickup_state():
	var item: Area2D = _make_item(Vector2(30, 0))
	_pick_up_item(item)
	player.current_zone = ZoneScript.ZoneType.BEACH
	player.drop_item()
	assert_eq(item.current_state, item.State.PICKUP)
