extends GutTest

var item: Area2D

func before_each():
	item = preload("res://scenes/item/item.tscn").instantiate()
	add_child_autofree(item)

func test_turret_exports_exist():
	assert_eq(item.attack_range, 150.0)
	assert_eq(item.attack_rate, 1.0)
	assert_eq(item.projectile_speed, 300.0)
	assert_eq(item.projectile_damage, 10.0)

func test_detection_area_disabled_in_pickup_state():
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	assert_false(detection.monitoring)

func test_detection_area_enabled_in_turret_state():
	item.drop()
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	assert_true(detection.monitoring)

func test_shoot_timer_stopped_in_pickup_state():
	var timer: Timer = item.get_node("TurretState/ShootTimer")
	assert_true(timer.is_stopped())

func test_shoot_timer_running_in_turret_state():
	item.drop()
	var timer: Timer = item.get_node("TurretState/ShootTimer")
	assert_false(timer.is_stopped())

func test_find_target_returns_null_when_empty():
	item.drop()
	assert_null(item._find_target())

func test_pick_up_stops_turret_systems():
	item.drop()
	item.pick_up()
	var detection: Area2D = item.get_node("TurretState/DetectionArea")
	var timer: Timer = item.get_node("TurretState/ShootTimer")
	assert_false(detection.monitoring)
	assert_true(timer.is_stopped())
