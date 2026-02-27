extends "res://scenes/item/base_item.gd"

@export var attack_range: float = 150.0
@export var attack_rate: float = 1.0
@export var projectile_speed: float = 300.0
@export var projectile_damage: float = 10.0

var _monsters_in_range: Array[Area2D] = []
var _projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

func _ready():
	super._ready()
	$ActiveState/DetectionArea.area_entered.connect(_on_detection_area_entered)
	$ActiveState/DetectionArea.area_exited.connect(_on_detection_area_exited)
	$ActiveState/ShootTimer.timeout.connect(_on_shoot_timer_timeout)
	_update_turret_systems()

func has_preview() -> bool:
	return true

func use(_context: Dictionary) -> int:
	return UseResult.PLACE

func activate() -> void:
	super.activate()
	_update_turret_systems()

func pick_up():
	deactivate()
	super.pick_up()

func store_in_inventory() -> void:
	deactivate()
	super.store_in_inventory()

func deactivate() -> void:
	_monsters_in_range.clear()
	$ActiveState/DetectionArea.monitoring = false
	$ActiveState/ShootTimer.stop()

# --- Virtual methods: override in turret subclasses ---

func _find_target() -> Area2D:
	if _monsters_in_range.is_empty():
		return null
	var closest: Area2D = null
	var closest_dist: float = INF
	for monster in _monsters_in_range:
		if not is_instance_valid(monster):
			continue
		var dist: float = global_position.distance_to(monster.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = monster
	return closest

func _attack(target: Area2D) -> void:
	var projectile: Area2D = _projectile_scene.instantiate()
	projectile.global_position = global_position
	var dir: Vector2 = (target.global_position - global_position).normalized()
	projectile.direction = dir
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	get_tree().current_scene.add_child(projectile)

# --- Internal ---

func _update_turret_systems() -> void:
	var active: bool = current_state == State.ACTIVE
	$ActiveState/DetectionArea.monitoring = active
	if active:
		$ActiveState/DetectionArea/CollisionShape2D.shape.radius = attack_range
		$ActiveState/ShootTimer.wait_time = 1.0 / attack_rate
		$ActiveState/ShootTimer.start()
	else:
		$ActiveState/ShootTimer.stop()

func _on_detection_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		_monsters_in_range.append(area)

func _on_detection_area_exited(area: Area2D) -> void:
	_monsters_in_range.erase(area)

func _on_shoot_timer_timeout() -> void:
	_monsters_in_range = _monsters_in_range.filter(func(m): return is_instance_valid(m))
	var target: Area2D = _find_target()
	if target:
		_attack(target)
