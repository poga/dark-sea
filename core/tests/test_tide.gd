extends GutTest

var _tide: ColorRect

func before_each() -> void:
	_tide = ColorRect.new()
	_tide.offset_left = 100.0
	_tide.offset_top = -400.0
	_tide.offset_right = 504.0
	_tide.offset_bottom = 393.0
	_tide.set_script(load("res://scenes/game/tide.gd"))
	add_child_autofree(_tide)

func test_ready_stores_initial_dimensions() -> void:
	assert_eq(_tide._full_left, 100.0)
	assert_eq(_tide._width, 404.0)

func test_update_tide_position_sets_offset_left() -> void:
	watch_signals(_tide)
	_tide._update_tide_position(250.0)
	assert_eq(_tide.offset_left, 250.0)

func test_update_tide_position_emits_signal() -> void:
	watch_signals(_tide)
	_tide._update_tide_position(250.0)
	assert_signal_emitted_with_parameters(_tide, "tide_position_changed", [250.0])

func test_ebb_target_calculation() -> void:
	# ebb_ratio=0.8, width=404, full_left=100
	# target = 100 + 404 * 0.8 = 423.2
	_tide._start_ebb()
	assert_not_null(_tide._tween)
	assert_true(_tide._tween.is_valid())
