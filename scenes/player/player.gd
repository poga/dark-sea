extends CharacterBody2D

const ZoneScript = preload("res://scenes/zones/zone.gd")

signal item_picked_up(item: Area2D)
signal item_dropped(item: Area2D, drop_position: Vector2)

@export var speed: float = 200.0
@export var camera_smoothing_speed: float = 5.0

var held_item: Area2D = null
var _items_in_range: Array[Area2D] = []

func _ready():
	$Camera2D.position_smoothing_speed = camera_smoothing_speed
	$PickupZone.area_entered.connect(_on_pickup_zone_area_entered)
	$PickupZone.area_exited.connect(_on_pickup_zone_area_exited)

func _physics_process(_delta):
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if held_item:
			if can_drop():
				drop_item()
		else:
			pick_up_nearest_item()

func get_nearest_item() -> Area2D:
	if _items_in_range.is_empty():
		return null
	var nearest: Area2D = null
	var nearest_distance: float = INF
	for item in _items_in_range:
		var distance: float = global_position.distance_to(item.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = item
	return nearest

func pick_up_nearest_item():
	var nearest: Area2D = get_nearest_item()
	if nearest == null:
		return
	held_item = nearest
	_items_in_range.erase(nearest)
	nearest.pick_up()
	nearest.get_parent().remove_child(nearest)
	$HoldPosition.add_child(nearest)
	nearest.position = Vector2.ZERO
	item_picked_up.emit(nearest)

func get_current_zone():
	for area in $PickupZone.get_overlapping_areas():
		if "zone_type" in area:
			return area.zone_type
	return null

func can_drop() -> bool:
	var zone = get_current_zone()
	if zone == null:
		return false
	return zone != ZoneScript.ZoneType.SEA

func drop_item():
	var item: Area2D = held_item
	var drop_pos: Vector2 = global_position
	held_item = null
	var zone = get_current_zone()
	if zone == ZoneScript.ZoneType.TOWER:
		item.drop()
	else:
		item.drop_as_pickup()
	$HoldPosition.remove_child(item)
	get_parent().add_child(item)
	item.global_position = drop_pos
	item_dropped.emit(item, drop_pos)

func _on_pickup_zone_area_entered(area: Area2D):
	if area != held_item and area.has_method("pick_up"):
		_items_in_range.append(area)

func _on_pickup_zone_area_exited(area: Area2D):
	if not "zone_type" in area:
		_items_in_range.erase(area)
