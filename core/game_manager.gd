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
signal pickup_tween_requested(texture: Texture2D, screen_pos: Vector2, slot: int)
signal resource_changed(type: String, new_amount: int)
signal character_selected(id: String)
signal character_unlocked(id: String)

enum Phase { DAY, NIGHT }

const INVENTORY_SIZE: int = 8
const CHARACTERS_PATH: String = "res://data/characters.json"
const SAVE_PATH: String = "user://save_data.json"

var state: int = 0
var current_phase: Phase = Phase.DAY
var gold: int = 0
var resources: Dictionary = {}
var characters: Dictionary = {}
var selected_character: String = ""
var _unlocked_overrides: Array[String] = []
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
	load_characters()

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
	add_resource("gold", amount)

func add_resource(type: String, amount: int) -> void:
	if not resources.has(type):
		resources[type] = 0
	resources[type] += amount
	resource_changed.emit(type, resources[type])

func get_resource(type: String) -> int:
	return resources.get(type, 0)

func reset_for_new_game() -> void:
	gold = 0
	resources = {}
	inventory.resize(INVENTORY_SIZE)
	inventory.fill(null)
	active_slot = 0

# --- Character management ---

func load_characters() -> void:
	var file := FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
	if file == null:
		push_error("GameManager: Could not open %s" % CHARACTERS_PATH)
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		push_error("GameManager: JSON parse error in %s: %s" % [CHARACTERS_PATH, json.get_error_message()])
		return
	characters = json.data
	_load_unlocks()

func set_character(id: String) -> void:
	if not characters.has(id):
		push_error("GameManager: Unknown character '%s'" % id)
		return
	selected_character = id
	character_selected.emit(id)

func get_character() -> Dictionary:
	if selected_character == "" or not characters.has(selected_character):
		return {}
	return characters[selected_character]

func is_character_unlocked(id: String) -> bool:
	if _unlocked_overrides.has(id):
		return true
	if not characters.has(id):
		return false
	return not characters[id].get("locked", false)

func unlock_character(id: String) -> void:
	if not _unlocked_overrides.has(id):
		_unlocked_overrides.append(id)
		_save_unlocks()
	character_unlocked.emit(id)

func get_unlocked_characters() -> Array:
	var result: Array = []
	for id: String in characters:
		if is_character_unlocked(id):
			result.append(id)
	return result

func apply_character_loadout() -> void:
	var data: Dictionary = get_character()
	if data.is_empty():
		return
	# Apply starting resources
	var starting_resources: Dictionary = data.get("starting_resources", {})
	for type: String in starting_resources:
		add_resource(type, int(starting_resources[type]))
	# Apply starting items
	var starting_items: Array = data.get("starting_items", [])
	for item_path: String in starting_items:
		var scene: PackedScene = load(item_path)
		if scene == null:
			push_error("GameManager: Could not load item scene '%s'" % item_path)
			continue
		var item: Area2D = scene.instantiate()
		try_pickup(item)

func _save_unlocks() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameManager: Could not write %s" % SAVE_PATH)
		return
	var data: Dictionary = {"unlocked_characters": _unlocked_overrides}
	file.store_string(JSON.stringify(data, "\t"))

func _load_unlocks() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		return
	var data: Dictionary = json.data
	if data.has("unlocked_characters"):
		_unlocked_overrides.assign(data["unlocked_characters"])

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
	var screen_pos: Vector2 = _world_to_screen(item.global_position)
	var icon: Texture2D = item.inventory_icon if "inventory_icon" in item else null
	if item.get_parent():
		item.get_parent().remove_child(item)
	item.store_in_inventory()
	inventory[slot] = item
	if slot == active_slot and _player:
		_player.get_node("HoldPosition").add_child(item)
		item.position = Vector2.ZERO
	inventory_changed.emit(slot, item)
	if icon:
		pickup_tween_requested.emit(icon, screen_pos, slot)
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

func swap_slots(a: int, b: int) -> void:
	if a == b:
		return
	if a < 0 or a >= INVENTORY_SIZE or b < 0 or b >= INVENTORY_SIZE:
		return
	var item_a: Area2D = inventory[a]
	var item_b: Area2D = inventory[b]
	inventory[a] = item_b
	inventory[b] = item_a
	# Handle HoldPosition reparenting if active slot is involved
	if _player:
		var hold: Marker2D = _player.get_node("HoldPosition")
		if a == active_slot or b == active_slot:
			# Remove old active item from HoldPosition
			if a == active_slot and item_a != null:
				hold.remove_child(item_a)
			elif b == active_slot and item_b != null:
				hold.remove_child(item_b)
			# Add new active item to HoldPosition
			var new_active: Area2D = inventory[active_slot]
			if new_active != null:
				hold.add_child(new_active)
				new_active.position = Vector2.ZERO
	inventory_changed.emit(a, inventory[a])
	inventory_changed.emit(b, inventory[b])

func drop_item_from_slot(slot: int, target_position: Vector2) -> void:
	if slot < 0 or slot >= INVENTORY_SIZE:
		return
	var item: Area2D = inventory[slot]
	if item == null:
		return
	inventory[slot] = null
	if _player and slot == active_slot:
		_player.get_node("HoldPosition").remove_child(item)
	_player.get_parent().add_child(item)
	item.global_position = target_position
	item.drop_as_pickup()
	inventory_changed.emit(slot, null)

func use_active_item(target_position: Vector2) -> void:
	var item: Area2D = get_active_item()
	if item == null:
		return
	if item.is_swinging:
		return
	item_use_attempted.emit(item)
	var context: Dictionary = {
		"target_position": target_position,
		"player": _player,
	}
	if not item.can_use(context):
		item_use_failed.emit(item)
		return
	var facing: Vector2 = _player.facing_direction if _player else Vector2.RIGHT
	item.play_swing(facing, func(): _apply_item_use(item, context))

func _apply_item_use(item: Area2D, context: Dictionary) -> void:
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
			item.global_position = context.target_position
			item.activate()
			inventory_changed.emit(active_slot, null)
	item_used.emit(item, result)

func _find_empty_slot() -> int:
	for i in range(INVENTORY_SIZE):
		if inventory[i] == null:
			return i
	return -1

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	return canvas_transform * world_pos
