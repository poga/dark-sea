extends Node

const DROP_TABLE_PATH: String = "res://data/drop_tables.json"

var drop_tables: Dictionary = {}
var _preloaded_item_scenes: Dictionary = {}
var _pickup_scene: PackedScene = preload("res://scenes/pickup/resource_pickup.tscn")

var resource_colors: Dictionary = {
	"gold": Color(1, 0.84, 0, 1),
	"bones": Color(0.9, 0.9, 0.9, 1),
}

func _ready() -> void:
	load_drop_tables()

func load_drop_tables() -> void:
	var file := FileAccess.open(DROP_TABLE_PATH, FileAccess.READ)
	if file == null:
		push_error("DropManager: Could not open %s" % DROP_TABLE_PATH)
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		push_error("DropManager: JSON parse error in %s: %s" % [DROP_TABLE_PATH, json.get_error_message()])
		return
	drop_tables = json.data
	_preload_scenes()

func _preload_scenes() -> void:
	_preloaded_item_scenes.clear()
	for monster_type: String in drop_tables:
		var drops: Array = drop_tables[monster_type]["drops"]
		for entry: Dictionary in drops:
			if entry["type"] == "item" and entry.has("scene"):
				var scene_path: String = entry["scene"]
				if not _preloaded_item_scenes.has(scene_path):
					_preloaded_item_scenes[scene_path] = load(scene_path)

func roll_drops_for(monster_type: String) -> Array:
	if not drop_tables.has(monster_type):
		return []
	var results: Array = []
	var drops: Array = drop_tables[monster_type]["drops"]
	for entry: Dictionary in drops:
		if randf() >= entry["chance"]:
			continue
		if entry["type"] == "item":
			results.append({
				"type": "item",
				"scene": entry["scene"],
			})
		else:
			var amount: int = randi_range(int(entry["min"]), int(entry["max"]))
			results.append({
				"type": entry["type"],
				"amount": amount,
			})
	return results

func spawn_drops(monster_type: String, position: Vector2, parent: Node) -> void:
	var results: Array = roll_drops_for(monster_type)
	for result: Dictionary in results:
		if result["type"] == "item":
			_spawn_item_drop(result, position, parent)
		else:
			_spawn_resource_drop(result, position, parent)

func _spawn_resource_drop(result: Dictionary, position: Vector2, parent: Node) -> void:
	for _i in result["amount"]:
		var pickup: Area2D = _pickup_scene.instantiate()
		pickup.resource_type = result["type"]
		pickup.value = 1
		pickup.global_position = position
		var angle: float = randf() * TAU
		var speed: float = randf_range(150.0, 300.0)
		var burst_vel: Vector2 = Vector2.from_angle(angle) * speed
		if resource_colors.has(result["type"]):
			pickup.get_node("ColorRect").color = resource_colors[result["type"]]
		parent.add_child(pickup)
		pickup.start_spawning(burst_vel)

func _spawn_item_drop(result: Dictionary, position: Vector2, parent: Node) -> void:
	var scene_path: String = result["scene"]
	var scene: PackedScene = _preloaded_item_scenes.get(scene_path)
	if scene == null:
		push_error("DropManager: No preloaded scene for %s" % scene_path)
		return
	var item: Area2D = scene.instantiate()
	item.global_position = position
	parent.add_child(item)
