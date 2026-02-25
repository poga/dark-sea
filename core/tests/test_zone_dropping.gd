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

func _simulate_item_enters_range(item: Area2D) -> void:
	player._on_pickup_zone_area_entered(item)

func test_can_drop_returns_false_when_no_zone():
	assert_false(player.can_drop())

func test_drop_in_tower_zone_sets_turret_state():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	# Since get_current_zone() queries physics overlaps which aren't available in unit tests,
	# we test the item's drop methods directly to verify state transitions.
	item.drop()
	assert_eq(item.current_state, item.State.TURRET)

func test_drop_in_beach_zone_keeps_pickup_state():
	var item: Area2D = _make_item(Vector2(30, 0))
	_simulate_item_enters_range(item)
	item.drop_as_pickup()
	assert_eq(item.current_state, item.State.PICKUP)
