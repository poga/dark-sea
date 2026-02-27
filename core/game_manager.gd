extends Node

signal state_changed(new_state)
signal day_started
signal night_started
signal phase_changed(phase: Phase)
signal gold_changed(new_amount: int)
signal inventory_changed(slot: int, item: Area2D)
signal active_slot_changed(slot: int)
signal item_use_attempted(item: Area2D)
signal item_used(item: Area2D, result: int)
signal item_use_failed(item: Area2D)

enum Phase { DAY, NIGHT }

const INVENTORY_SIZE: int = 8

var state: int = 0
var current_phase: Phase = Phase.DAY
var gold: int = 0
var inventory: Array[Area2D] = []
var active_slot: int = 0
var _player: CharacterBody2D

@export var day_duration: float = 30.0
@export var night_duration: float = 30.0

var _phase_timer: Timer

func _ready() -> void:
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	_phase_timer.timeout.connect(_on_phase_timer_timeout)
	add_child(_phase_timer)
	inventory.resize(INVENTORY_SIZE)
	inventory.fill(null)

func increment_state():
	state += 1
	state_changed.emit(state)
	return state

func start_cycle() -> void:
	_phase_timer.stop()
	current_phase = Phase.DAY
	day_started.emit()
	phase_changed.emit(current_phase)
	_phase_timer.wait_time = day_duration
	_phase_timer.start()

func _on_phase_timer_timeout() -> void:
	if current_phase == Phase.DAY:
		current_phase = Phase.NIGHT
		night_started.emit()
		_phase_timer.wait_time = night_duration
	else:
		current_phase = Phase.DAY
		day_started.emit()
		_phase_timer.wait_time = day_duration
	phase_changed.emit(current_phase)
	_phase_timer.start()

func skip_to_next_phase() -> void:
	_phase_timer.stop()
	_on_phase_timer_timeout()

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

# --- Inventory management ---

func register_player(player: CharacterBody2D) -> void:
	_player = player

func reset_inventory() -> void:
	inventory.resize(INVENTORY_SIZE)
	inventory.fill(null)
	active_slot = 0
	_player = null

func get_active_item() -> Area2D:
	return inventory[active_slot]

func try_pickup(item: Area2D) -> bool:
	var slot: int = _find_empty_slot()
	if slot == -1:
		return false
	item.get_parent().remove_child(item)
	item.store_in_inventory()
	inventory[slot] = item
	if slot == active_slot and _player:
		_player.get_node("HoldPosition").add_child(item)
		item.position = Vector2.ZERO
	inventory_changed.emit(slot, item)
	return true

func switch_slot(slot: int) -> void:
	if slot < 0 or slot >= INVENTORY_SIZE:
		return
	if slot == active_slot:
		return
	if _player:
		var old_item: Area2D = inventory[active_slot]
		if old_item != null:
			_player.get_node("HoldPosition").remove_child(old_item)
		active_slot = slot
		var new_item: Area2D = inventory[active_slot]
		if new_item != null:
			_player.get_node("HoldPosition").add_child(new_item)
			new_item.position = Vector2.ZERO
	else:
		active_slot = slot
	active_slot_changed.emit(active_slot)

func switch_next() -> void:
	switch_slot((active_slot + 1) % INVENTORY_SIZE)

func switch_prev() -> void:
	switch_slot((active_slot - 1 + INVENTORY_SIZE) % INVENTORY_SIZE)

func use_active_item(target_position: Vector2) -> void:
	var item: Area2D = get_active_item()
	if item == null:
		return
	item_use_attempted.emit(item)
	var context: Dictionary = {
		"target_position": target_position,
		"player": _player,
	}
	if not item.can_use(context):
		item_use_failed.emit(item)
		return
	var result: int = item.use(context)
	if result == item.UseResult.NOTHING:
		item_use_failed.emit(item)
		return
	match result:
		item.UseResult.KEEP:
			pass  # item stays in inventory
		item.UseResult.CONSUME:
			inventory[active_slot] = null
			if _player:
				_player.get_node("HoldPosition").remove_child(item)
			item.queue_free()
			inventory_changed.emit(active_slot, null)
		item.UseResult.PLACE:
			inventory[active_slot] = null
			if _player:
				_player.get_node("HoldPosition").remove_child(item)
				_player.get_parent().add_child(item)
			item.global_position = target_position
			item.activate()
			inventory_changed.emit(active_slot, null)
	item_used.emit(item, result)

func _find_empty_slot() -> int:
	for i in range(INVENTORY_SIZE):
		if inventory[i] == null:
			return i
	return -1
