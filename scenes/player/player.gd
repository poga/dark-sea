extends CharacterBody2D

const ZoneScript = preload("res://scenes/zones/zone.gd")
const INVENTORY_SIZE: int = 8

signal item_picked_up(item: Area2D)
signal item_dropped(item: Area2D, drop_position: Vector2)
signal inventory_changed(slot: int, item: Area2D)
signal active_slot_changed(slot: int)

@export var speed: float = 200.0
@export var camera_smoothing_speed: float = 5.0
@export var reclaim_hold_time: float = 1.0

var inventory: Array[Area2D] = []
var active_slot: int = 0
var _items_in_range: Array[Area2D] = []
var _turrets_in_range: Array[Area2D] = []
var _reclaim_timer: float = 0.0
var _is_reclaiming: bool = false

func _ready():
	inventory.resize(INVENTORY_SIZE)
	inventory.fill(null)
	$Camera2D.position_smoothing_speed = camera_smoothing_speed
	$PickupZone.area_entered.connect(_on_pickup_zone_area_entered)
	$PickupZone.area_exited.connect(_on_pickup_zone_area_exited)

func _physics_process(delta):
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	if _is_reclaiming:
		_reclaim_timer += delta
		if _reclaim_timer >= reclaim_hold_time:
			_is_reclaiming = false
			_reclaim_timer = 0.0
			var target: Area2D = _get_nearest_turret()
			if target:
				reclaim_turret(target)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if not _turrets_in_range.is_empty():
			_is_reclaiming = true
			_reclaim_timer = 0.0
		return
	if event.is_action_released("interact"):
		_is_reclaiming = false
		_reclaim_timer = 0.0
		return
	if event.is_action_pressed("drop"):
		if has_active_item() and can_drop():
			drop_item()
		return
	# Direct slot selection (1-8)
	for i in range(INVENTORY_SIZE):
		var action_name: String = "slot_%d" % (i + 1)
		if event.is_action_pressed(action_name):
			switch_to_slot(i)
			return
	if event.is_action_pressed("slot_next"):
		switch_next()
	elif event.is_action_pressed("slot_prev"):
		switch_prev()

func has_active_item() -> bool:
	return inventory[active_slot] != null

func _find_empty_slot() -> int:
	for i in range(INVENTORY_SIZE):
		if inventory[i] == null:
			return i
	return -1

func get_current_zone():
	for area in $PickupZone.get_overlapping_areas():
		if "zone_type" in area:
			return area.zone_type
	return null

func can_drop() -> bool:
	return get_current_zone() == ZoneScript.ZoneType.TOWER

func drop_item():
	var item: Area2D = inventory[active_slot]
	if item == null:
		return
	var drop_pos: Vector2 = global_position
	inventory[active_slot] = null
	item.drop()
	$HoldPosition.remove_child(item)
	get_parent().add_child(item)
	item.global_position = drop_pos
	inventory_changed.emit(active_slot, null)
	item_dropped.emit(item, drop_pos)
	_try_auto_pickup_from_range()

func switch_to_slot(slot: int) -> void:
	if slot < 0 or slot >= INVENTORY_SIZE:
		return
	if slot == active_slot:
		return
	var old_item: Area2D = inventory[active_slot]
	if old_item != null:
		$HoldPosition.remove_child(old_item)
	active_slot = slot
	var new_item: Area2D = inventory[active_slot]
	if new_item != null:
		$HoldPosition.add_child(new_item)
		new_item.position = Vector2.ZERO
	active_slot_changed.emit(active_slot)

func switch_next() -> void:
	switch_to_slot((active_slot + 1) % INVENTORY_SIZE)

func switch_prev() -> void:
	switch_to_slot((active_slot - 1 + INVENTORY_SIZE) % INVENTORY_SIZE)

func _try_auto_pickup(item: Area2D) -> void:
	var slot: int = _find_empty_slot()
	if slot == -1:
		return
	_items_in_range.erase(item)
	item.get_parent().remove_child(item)
	item.store_in_inventory()
	inventory[slot] = item
	if slot == active_slot:
		$HoldPosition.add_child(item)
		item.position = Vector2.ZERO
	inventory_changed.emit(slot, item)
	item_picked_up.emit(item)

func _try_auto_pickup_from_range() -> void:
	for item in _items_in_range.duplicate():
		if _find_empty_slot() == -1:
			break
		_try_auto_pickup(item)

func _get_nearest_turret() -> Area2D:
	var nearest: Area2D = null
	var nearest_dist: float = INF
	for turret in _turrets_in_range:
		if not is_instance_valid(turret):
			continue
		var dist: float = global_position.distance_to(turret.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = turret
	return nearest

func reclaim_turret(turret: Area2D) -> void:
	var slot: int = _find_empty_slot()
	if slot == -1:
		return
	_turrets_in_range.erase(turret)
	turret.get_parent().remove_child(turret)
	turret.store_in_inventory()
	inventory[slot] = turret
	if slot == active_slot:
		$HoldPosition.add_child(turret)
		turret.position = Vector2.ZERO
	inventory_changed.emit(slot, turret)
	item_picked_up.emit(turret)

func _on_pickup_zone_area_entered(area: Area2D):
	if inventory.has(area):
		return
	if area.has_method("pick_up") and area.current_state == area.State.PICKUP:
		_items_in_range.append(area)
		_try_auto_pickup.call_deferred(area)
	elif area.has_method("pick_up") and area.current_state == area.State.TURRET:
		_turrets_in_range.append(area)

func _on_pickup_zone_area_exited(area: Area2D):
	if not "zone_type" in area:
		_items_in_range.erase(area)
		_turrets_in_range.erase(area)
		if _turrets_in_range.is_empty():
			_reclaim_timer = 0.0
			_is_reclaiming = false
