extends GutTest

var item: Area2D

func before_each():
	item = preload("res://scenes/item/turret_item.tscn").instantiate()
	add_child_autofree(item)

func test_inherits_base_item_state():
	assert_eq(item.current_state, item.State.PICKUP)

func test_has_turret_exports():
	assert_eq(item.attack_range, 150.0)
	assert_eq(item.attack_rate, 1.0)
	assert_eq(item.projectile_speed, 300.0)
	assert_eq(item.projectile_damage, 10.0)

func test_has_preview_returns_true():
	assert_true(item.has_preview())

func test_use_returns_place():
	var result: int = item.use({})
	assert_eq(result, item.UseResult.PLACE)

func test_detection_area_disabled_in_pickup_state():
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	assert_false(detection.monitoring)

func test_detection_area_enabled_after_activate():
	item.activate()
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	assert_true(detection.monitoring)

func test_shoot_timer_stopped_in_pickup_state():
	var timer: Timer = item.get_node("TurretState/ShootTimer")
	assert_true(timer.is_stopped())

func test_shoot_timer_running_after_activate():
	item.activate()
	var timer: Timer = item.get_node("TurretState/ShootTimer")
	assert_false(timer.is_stopped())

func test_find_target_returns_null_when_empty():
	item.activate()
	assert_null(item._find_target())

func test_deactivate_stops_turret_systems():
	item.activate()
	item.deactivate()
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	var timer: Timer = item.get_node("TurretState/ShootTimer")
	assert_false(detection.monitoring)
	assert_true(timer.is_stopped())
