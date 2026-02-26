extends Area2D

signal picked_up_as_item
signal picked_up_as_turret
signal placed_as_turret

enum State { PICKUP, TURRET, INVENTORY }

@export var item_name: String = "Item"
@export var attack_range: float = 150.0
@export var attack_rate: float = 1.0
@export var projectile_speed: float = 300.0
@export var projectile_damage: float = 10.0
@export var inventory_icon: Texture2D

var current_state: State = State.PICKUP
var _monsters_in_range: Array[Area2D] = []
var _projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

func _ready():
	$PickupState/Label.text = item_name
	$TurretState/Label.text = item_name
	$InventoryState/Label.text = item_name
	$TurretState/DetectionArea.area_entered.connect(_on_detection_area_entered)
	$TurretState/DetectionArea.area_exited.connect(_on_detection_area_exited)
	$TurretState/ShootTimer.timeout.connect(_on_shoot_timer_timeout)
	_update_state_visuals()
	_update_turret_systems()

func pick_up():
	if current_state == State.TURRET:
		picked_up_as_turret.emit()
	else:
		picked_up_as_item.emit()
	current_state = State.PICKUP
	_monsters_in_range.clear()
	_update_state_visuals()
	_update_turret_systems()
	_on_turret_deactivated()

func drop():
	current_state = State.TURRET
	_update_state_visuals()
	_update_turret_systems()
	_on_turret_activated()
	placed_as_turret.emit()

func drop_as_pickup() -> void:
	current_state = State.PICKUP
	_update_state_visuals()
	_update_turret_systems()

func store_in_inventory() -> void:
	current_state = State.INVENTORY
	_monsters_in_range.clear()
	_update_state_visuals()
	_update_turret_systems()

# --- Virtual methods: override in custom items ---

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

func _on_turret_activated() -> void:
	pass

func _on_turret_deactivated() -> void:
	pass

func use(_player: CharacterBody2D) -> bool:
	return true

# --- Internal methods ---

func _update_state_visuals():
	$PickupState.visible = current_state == State.PICKUP
	$TurretState.visible = current_state == State.TURRET
	$InventoryState.visible = current_state == State.INVENTORY

func _update_turret_systems() -> void:
	var active: bool = current_state == State.TURRET
	$TurretState/DetectionArea.monitoring = active
	if active:
		$TurretState/DetectionArea/CollisionShape2D.shape.radius = attack_range
		$TurretState/ShootTimer.wait_time = 1.0 / attack_rate
		$TurretState/ShootTimer.start()
	else:
		$TurretState/ShootTimer.stop()

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
