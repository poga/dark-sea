extends HBoxContainer

@export var player_path: NodePath

var _player: CharacterBody2D
var _slots: Array[PanelContainer] = []

func _ready():
	_player = get_node(player_path)
	_player.inventory_changed.connect(_on_inventory_changed)
	_player.active_slot_changed.connect(_on_active_slot_changed)
	_build_slots()
	_update_active_highlight()

func _build_slots() -> void:
	for i in range(_player.INVENTORY_SIZE):
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(48, 48)
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)
		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		vbox.add_child(icon)
		var label: Label = Label.new()
		label.name = "SlotLabel"
		label.text = str(i + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
		add_child(panel)
		_slots.append(panel)

func _on_inventory_changed(slot: int, item: Area2D) -> void:
	var icon: TextureRect = _slots[slot].get_node("VBoxContainer/Icon")
	if item != null and item.inventory_icon != null:
		icon.texture = item.inventory_icon
	else:
		icon.texture = null

func _on_active_slot_changed(slot: int) -> void:
	_update_active_highlight()

func _update_active_highlight() -> void:
	for i in range(_slots.size()):
		var panel: PanelContainer = _slots[i]
		if i == _player.active_slot:
			panel.modulate = Color(1, 1, 0.5, 1)
		else:
			panel.modulate = Color(1, 1, 1, 0.7)
