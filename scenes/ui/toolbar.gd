extends HBoxContainer

var _slots: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var held_slot: int = -1
var _cursor_layer: CanvasLayer
var _cursor_icon: TextureRect

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	GameManager.inventory_changed.connect(_on_inventory_changed)
	GameManager.active_slot_changed.connect(_on_active_slot_changed)
	_build_slots()
	_build_cursor_icon()
	_update_active_highlight()

func _build_slots() -> void:
	for i in range(GameManager.INVENTORY_SIZE):
		var panel: PanelContainer = PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.custom_minimum_size = Vector2(48, 48)
		panel.gui_input.connect(_on_slot_gui_input.bind(i))
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)
		var icon: TextureRect = TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		vbox.add_child(icon)
		var label: Label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.name = "SlotLabel"
		label.text = str(i + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
		add_child(panel)
		_slots.append(panel)
		_icons.append(icon)

func _build_cursor_icon() -> void:
	_cursor_layer = CanvasLayer.new()
	_cursor_layer.layer = 100
	add_child(_cursor_layer)
	_cursor_icon = TextureRect.new()
	_cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cursor_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor_icon.custom_minimum_size = Vector2(32, 32)
	_cursor_icon.modulate = Color(1, 1, 1, 0.8)
	_cursor_icon.visible = false
	_cursor_layer.add_child(_cursor_icon)

func _process(_delta: float) -> void:
	if held_slot >= 0:
		_cursor_icon.global_position = get_global_mouse_position() - _cursor_icon.size / 2.0

func _on_slot_gui_input(event: InputEvent, slot: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	get_viewport().set_input_as_handled()
	if held_slot < 0:
		_try_pick_up(slot)
	elif held_slot == slot:
		_cancel_hold()
	else:
		_place_in_slot(slot)

func _unhandled_input(event: InputEvent) -> void:
	if held_slot < 0:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_drop_held_item()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_hold()
		get_viewport().set_input_as_handled()

func _try_pick_up(slot: int) -> void:
	if GameManager.inventory[slot] == null:
		return
	held_slot = slot
	_cursor_icon.texture = _icons[slot].texture
	_cursor_icon.visible = true
	_cursor_icon.global_position = get_global_mouse_position() - _cursor_icon.size / 2.0
	_icons[slot].texture = null

func _place_in_slot(target: int) -> void:
	GameManager.swap_slots(held_slot, target)
	_cancel_hold()

func _drop_held_item() -> void:
	var player: CharacterBody2D = GameManager._player
	if player:
		GameManager.drop_item_from_slot(held_slot, player.get_drop_position())
	_cancel_hold()

func _cancel_hold() -> void:
	if held_slot >= 0:
		# Restore icon from inventory (in case swap didn't happen)
		var item: Area2D = GameManager.inventory[held_slot]
		if item != null and item.inventory_icon != null:
			_icons[held_slot].texture = item.inventory_icon
	held_slot = -1
	_cursor_icon.visible = false

func _on_inventory_changed(slot: int, item: Area2D) -> void:
	var icon: TextureRect = _icons[slot]
	if item != null and item.inventory_icon != null:
		icon.texture = item.inventory_icon
	else:
		icon.texture = null

func _on_active_slot_changed(_slot: int) -> void:
	if held_slot >= 0:
		_cancel_hold()
	_update_active_highlight()

func get_slot_center(slot: int) -> Vector2:
	if slot < 0 or slot >= _icons.size():
		return Vector2.ZERO
	var icon: TextureRect = _icons[slot]
	return icon.global_position + icon.size / 2.0

func _update_active_highlight() -> void:
	for i in range(_slots.size()):
		var panel: PanelContainer = _slots[i]
		if i == GameManager.active_slot:
			panel.modulate = Color(1, 1, 0.5, 1)
		else:
			panel.modulate = Color(1, 1, 1, 0.7)
