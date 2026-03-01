extends GutTest

var player: CharacterBody2D

func before_each():
	GameManager.reset_inventory()
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	GameManager.register_player(player)
	# Attach lookahead script so tests work independently of .tscn wiring
	var camera: Camera2D = player.get_node("Camera2D")
	camera.set_script(preload("res://scenes/player/camera_lookahead.gd"))

func _get_camera() -> Camera2D:
	return player.get_node("Camera2D")

# --- Offset responds to facing direction ---

func test_offset_moves_toward_facing_direction():
	player.facing_direction = Vector2.RIGHT
	var camera: Camera2D = _get_camera()
	# Simulate several frames
	for i in range(60):
		camera._process(0.016)
	# Offset should have moved toward the right
	assert_gt(camera.offset.x, 0.0, "Camera offset should shift right")

func test_offset_moves_toward_left_facing():
	player.facing_direction = Vector2.LEFT
	var camera: Camera2D = _get_camera()
	for i in range(60):
		camera._process(0.016)
	assert_lt(camera.offset.x, 0.0, "Camera offset should shift left")

func test_offset_returns_to_center_when_facing_unchanged():
	var camera: Camera2D = _get_camera()
	# Face right for a while
	player.facing_direction = Vector2.RIGHT
	for i in range(60):
		camera._process(0.016)
	var offset_after_right: float = camera.offset.x
	assert_gt(offset_after_right, 0.0)
	# Now face left — offset should decrease
	player.facing_direction = Vector2.LEFT
	for i in range(120):
		camera._process(0.016)
	assert_lt(camera.offset.x, offset_after_right, "Offset should move toward left")

func test_offset_respects_lookahead_distance():
	var camera: Camera2D = _get_camera()
	camera.lookahead_distance = 100.0
	player.facing_direction = Vector2.RIGHT
	# Run many frames to converge
	for i in range(300):
		camera._process(0.016)
	# Should converge close to 100 pixels
	assert_almost_eq(camera.offset.x, 100.0, 5.0, "Should converge near lookahead_distance")

func test_offset_starts_at_zero():
	var camera: Camera2D = _get_camera()
	assert_eq(camera.offset, Vector2.ZERO, "Offset should start at zero")
