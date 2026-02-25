extends Node2D

@export var spawn_interval: float = 3.0
@export var spawn_x: float = 400.0
@export var spawn_y_min: float = -300.0
@export var spawn_y_max: float = 300.0

var _monster_scene: PackedScene = preload("res://scenes/monster/monster.tscn")

func _ready() -> void:
	$SpawnTimer.wait_time = spawn_interval
	$SpawnTimer.timeout.connect(_on_spawn_timer_timeout)
	GameManager.night_started.connect(_on_night_started)
	GameManager.day_started.connect(_on_day_started)

func _on_night_started() -> void:
	$SpawnTimer.start()

func _on_day_started() -> void:
	$SpawnTimer.stop()
	_cleanup_monsters()

func _cleanup_monsters() -> void:
	var monsters_node: Node = get_parent().get_node("Monsters")
	for monster in monsters_node.get_children():
		monster.queue_free()

func _on_spawn_timer_timeout() -> void:
	var monster: Area2D = _monster_scene.instantiate()
	var spawn_y: float = randf_range(spawn_y_min, spawn_y_max)
	monster.global_position = Vector2(spawn_x, spawn_y)
	get_parent().get_node("Monsters").add_child(monster)
