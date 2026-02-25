extends Node2D

## Item Spawner — controls what items spawn each day.
## Designers: edit item_pool and items_per_day to change spawning behavior.
## The spawn_area export is set in the editor to an Area2D with a rectangular CollisionShape2D.

@export var spawn_area_path: NodePath
var spawn_area: Area2D

# --- Item pool: edit this to change what spawns ---
# Each entry has a scene and a weight (higher = more likely).
var item_pool: Array[Dictionary] = [
	{ "scene": preload("res://scenes/item/item.tscn"), "weight": 3 },
	{ "scene": preload("res://scenes/item/aoe_item.tscn"), "weight": 1 },
]

# --- Spawning rules: edit this to change how many spawn ---
@export var items_per_day: int = 4

# --- Internal tracking ---
var _spawned_items: Array[Area2D] = []

func _ready() -> void:
	if spawn_area_path:
		spawn_area = get_node(spawn_area_path) as Area2D
	GameManager.day_started.connect(_on_day_started)
	GameManager.night_started.connect(_on_night_started)

func _on_day_started() -> void:
	_spawn_items()

func _on_night_started() -> void:
	_cleanup_uncollected_items()

func _spawn_items() -> void:
	if spawn_area == null:
		push_error("ItemSpawner: spawn_area is not assigned.")
		return
	var total_weight: float = 0.0
	for entry in item_pool:
		total_weight += entry["weight"]

	for _i in items_per_day:
		var item_scene: PackedScene = _pick_weighted_random(total_weight)
		var item: Area2D = item_scene.instantiate()
		item.global_position = _random_point_in_spawn_area()
		get_parent().add_child(item)
		_spawned_items.append(item)

func _pick_weighted_random(total_weight: float) -> PackedScene:
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for entry in item_pool:
		cumulative += entry["weight"]
		if roll <= cumulative:
			return entry["scene"]
	return item_pool[-1]["scene"]

func _random_point_in_spawn_area() -> Vector2:
	var shape: CollisionShape2D = spawn_area.get_child(0) as CollisionShape2D
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	var extents: Vector2 = rect.size / 2.0
	var local_pos: Vector2 = Vector2(
		randf_range(-extents.x, extents.x),
		randf_range(-extents.y, extents.y)
	)
	return spawn_area.global_position + shape.position + local_pos

func _cleanup_uncollected_items() -> void:
	for item in _spawned_items:
		if is_instance_valid(item) and item.current_state == item.State.PICKUP:
			item.queue_free()
	_spawned_items.clear()
