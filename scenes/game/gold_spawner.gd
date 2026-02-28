extends Node2D

## Gold Spawner — spawns gold pickups during day, cleans up sea-zone gold at night.
## Designers: adjust gold_per_day to control daytime gold spawning.

@export var spawn_area_path: NodePath
@export var sea_zone_path: NodePath
@export var gold_per_day: int = 5
@export var tide_path: NodePath

var _gold_scene: PackedScene = preload("res://scenes/pickup/resource_pickup.tscn")
var _spawn_area: Area2D
var _sea_zone: Area2D
var _tide: ColorRect
var _spawned_gold: Array[Area2D] = []

func _ready() -> void:
	if spawn_area_path:
		_spawn_area = get_node(spawn_area_path) as Area2D
	if sea_zone_path:
		_sea_zone = get_node(sea_zone_path) as Area2D
	if tide_path:
		_tide = get_node(tide_path) as ColorRect
		_tide.tide_position_changed.connect(_on_tide_position_changed)
		_tide.tide_risen.connect(_on_tide_risen)
	GameManager.day_started.connect(_on_day_started)
	GameManager.night_started.connect(_on_night_started)

func _on_day_started() -> void:
	_spawn_gold()

func _on_night_started() -> void:
	if _tide == null:
		_cleanup_sea_gold()

func _spawn_gold() -> void:
	if _spawn_area == null:
		push_error("GoldSpawner: spawn_area is not assigned.")
		return
	for _i in gold_per_day:
		var gold: Area2D = _gold_scene.instantiate()
		gold.global_position = _random_point_in_spawn_area()
		if _tide:
			gold.visible = false
		get_parent().add_child(gold)
		_spawned_gold.append(gold)

func _random_point_in_spawn_area() -> Vector2:
	var shape: CollisionShape2D = _spawn_area.get_child(0) as CollisionShape2D
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	var extents: Vector2 = rect.size / 2.0
	var local_pos: Vector2 = Vector2(
		randf_range(-extents.x, extents.x),
		randf_range(-extents.y, extents.y)
	)
	return _spawn_area.global_position + shape.position + local_pos

func _cleanup_sea_gold() -> void:
	if _sea_zone == null:
		push_error("GoldSpawner: sea_zone is not assigned.")
		return
	var zone_pos: Vector2 = _sea_zone.global_position
	var zone_half_width: float = _sea_zone.zone_width / 2.0
	var zone_left: float = zone_pos.x - zone_half_width
	var zone_right: float = zone_pos.x + zone_half_width
	for gold in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(gold) and gold.global_position.x >= zone_left and gold.global_position.x <= zone_right:
			gold.queue_free()

func _on_tide_position_changed(left_edge_x: float) -> void:
	for gold in _spawned_gold:
		if not is_instance_valid(gold):
			continue
		gold.visible = gold.global_position.x < left_edge_x

func _on_tide_risen() -> void:
	_cleanup_sea_gold()
	_spawned_gold.clear()
