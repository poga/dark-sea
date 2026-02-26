extends CharacterBody2D

const ZoneScript = preload("res://scenes/zones/zone.gd")
const INVENTORY_SIZE: int = 8

signal item_picked_up(item: Area2D)
signal item_dropped(item: Area2D, drop_position: Vector2)
signal inventory_changed(slot: int, item: Area2D)
signal active_slot_changed(slot: int)

@export var speed: float = 200.0
@export var camera_smoothing_speed: float = 5.0
@export var drop_distance: float = 80.0

var facing_direction: Vector2 = Vector2.RIGHT
var inventory: Array[Area2D] = []
var active_slot: int = 0
var _items_in_range: Array[Area2D] = []

func _ready():
	inventory.resize(INVENTORY_SIZE)
	inventory.fill(null)
	$Camera2D.position_smoothing_speed = camera_smoothing_speed
	$PickupZone.area_entered.connect(_on_pickup_zone_area_entered)
	$PickupZone.area_exited.connect(_on_pickup_zone_area_exited)

func _physics_process(_delta):
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	# Update facing direction: joystick overrides mouse
	var look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.is_zero_approx():
		look = get_global_mouse_position() - global_position
	facing_direction = snap_to_cardinal(look)

	# Update drop preview
	var preview: Node2D = $DropPreview
	if has_active_item():
		preview.visible = true
		preview.global_position = get_drop_position()
		preview.update_state(can_drop())
	else:
		preview.visible = false

func snap_to_cardinal(raw: Vector2) -> Vector2:
	if raw.is_zero_approx():
		return facing_direction
	if absf(raw.x) >= absf(raw.y):
		return Vector2.RIGHT if raw.x >= 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if raw.y >= 0 else Vector2.UP

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("use"):
		if has_active_item() and can_drop():
			use_item()
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
	var drop_pos: Vector2 = get_drop_position()
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = drop_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results: Array[Dictionary] = space_state.intersect_point(query)
	for result in results:
		var collider = result["collider"]
		if "zone_type" in collider and collider.zone_type == ZoneScript.ZoneType.TOWER:
			return true
	return false

func get_drop_position() -> Vector2:
	return global_position + facing_direction * drop_distance

func drop_item():
	var item: Area2D = inventory[active_slot]
	if item == null:
		return
	var drop_pos: Vector2 = get_drop_position()
	inventory[active_slot] = null
	item.drop()
	$HoldPosition.remove_child(item)
	get_parent().add_child(item)
	item.global_position = drop_pos
	inventory_changed.emit(active_slot, null)
	item_dropped.emit(item, drop_pos)
	_try_auto_pickup_from_range()

func use_item():
	var item: Area2D = inventory[active_slot]
	if item == null:
		return
	if item.use(self):
		drop_item()

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
	if inventory.has(item):
		return
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

func _on_pickup_zone_area_entered(area: Area2D):
	if not inventory.has(area) and area.has_method("pick_up") and area.current_state == area.State.PICKUP:
		_items_in_range.append(area)
		_try_auto_pickup(area)

func _on_pickup_zone_area_exited(area: Area2D):
	if not "zone_type" in area:
		_items_in_range.erase(area)
