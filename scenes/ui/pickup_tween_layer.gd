extends Control

@export var duration: float = 0.35
@export var icon_size: Vector2 = Vector2(32, 32)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.pickup_tween_requested.connect(_on_pickup_tween_requested)

func _on_pickup_tween_requested(texture: Texture2D, screen_pos: Vector2, slot: int) -> void:
	var toolbar: HBoxContainer = _find_toolbar()
	if toolbar == null:
		return
	var target_pos: Vector2 = toolbar.get_slot_center(slot)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	icon.position = screen_pos - icon_size / 2.0
	add_child(icon)

	var tween: Tween = create_tween()
	tween.tween_property(icon, "position", target_pos - icon_size / 2.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(icon.queue_free)

func _find_toolbar() -> HBoxContainer:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	for child in parent_node.get_children():
		if child is HBoxContainer and child.has_method("get_slot_center"):
			return child
	return null
