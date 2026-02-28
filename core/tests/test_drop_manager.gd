extends GutTest

func before_each() -> void:
	GameManager.resources = {}

func test_load_drop_tables_parses_json():
	DropManager.load_drop_tables()
	assert_true(DropManager.drop_tables.has("default"), "Should have 'default' monster type")

func test_default_monster_has_drops():
	DropManager.load_drop_tables()
	var drops: Array = DropManager.drop_tables["default"]["drops"]
	assert_gt(drops.size(), 0, "Default monster should have at least one drop entry")

func test_roll_drops_returns_results():
	DropManager.load_drop_tables()
	# Roll with chance 1.0 gold should always produce results
	var results: Array = DropManager.roll_drops_for("default")
	assert_gt(results.size(), 0, "Should have at least one drop result")

func test_roll_drops_respects_chance_zero():
	# Manually set a drop table with 0% chance
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "gold", "chance": 0.0, "min": 1, "max": 1 }
			]
		}
	}
	var results: Array = DropManager.roll_drops_for("test_monster")
	assert_eq(results.size(), 0, "0% chance should never drop")

func test_roll_drops_respects_chance_one():
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "gold", "chance": 1.0, "min": 2, "max": 2 }
			]
		}
	}
	var results: Array = DropManager.roll_drops_for("test_monster")
	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "gold")
	assert_eq(results[0]["amount"], 2)

func test_roll_drops_amount_in_range():
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "gold", "chance": 1.0, "min": 1, "max": 5 }
			]
		}
	}
	# Roll many times to check range
	for _i in 20:
		var results: Array = DropManager.roll_drops_for("test_monster")
		assert_gte(results[0]["amount"], 1)
		assert_lte(results[0]["amount"], 5)

func test_roll_drops_unknown_type_returns_empty():
	DropManager.load_drop_tables()
	var results: Array = DropManager.roll_drops_for("nonexistent_monster")
	assert_eq(results.size(), 0)

func test_roll_drops_item_entry():
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "item", "chance": 1.0, "scene": "res://scenes/item/turret_item.tscn" }
			]
		}
	}
	DropManager._preload_scenes()
	var results: Array = DropManager.roll_drops_for("test_monster")
	assert_eq(results.size(), 1)
	assert_eq(results[0]["type"], "item")
	assert_true(results[0].has("scene"), "Item drops should include scene path")

func test_multiple_independent_drops():
	DropManager.drop_tables = {
		"test_monster": {
			"drops": [
				{ "type": "gold", "chance": 1.0, "min": 1, "max": 1 },
				{ "type": "bones", "chance": 1.0, "min": 1, "max": 1 }
			]
		}
	}
	var results: Array = DropManager.roll_drops_for("test_monster")
	assert_eq(results.size(), 2, "Both entries with 100% chance should drop")
