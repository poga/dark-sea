extends CharacterBody2D

@export var speed: float = 200.0
@export var drop_distance: float = 80.0

var facing_direction: Vector2 = Vector2.RIGHT
var _items_in_range: Array[Area2D] = []

func _ready():
	GameManager.register_player(self)
	_apply_character_data()
	$PickupZone.area_entered.connect(_on_pickup_zone_area_entered)
	$PickupZone.area_exited.connect(_on_pickup_zone_area_exited)

func _apply_character_data() -> void:
	var data: Dictionary = GameManager.get_character()
	if data.is_empty():
		return
	# Apply stats
	var stats: Dictionary = data.get("stats", {})
	if stats.has("speed"):
		speed = stats["speed"]
	# Apply sprite
	if data.has("sprite") and data["sprite"] != "":
		var texture: Texture2D = load(data["sprite"])
		if texture:
			$Sprite2D.texture = texture

func _physics_process(_delta):
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	# Update facing direction: joystick overrides mouse
	var look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.is_zero_approx():
		look = get_global_mouse_position() - global_position
	update_facing(look)

	# Update drop preview
	var preview: Node2D = $DropPreview
	var item: Area2D = GameManager.get_active_item()
	if item and item.has_preview():
		var context: Dictionary = {"target_position": get_drop_position(), "player": self}
		preview.visible = true
		preview.global_position = item.get_preview_position(context)
		preview.update_state(item.can_use(context))
	else:
		preview.visible = false

func update_facing(raw: Vector2) -> void:
	if not raw.is_zero_approx():
		facing_direction = raw.normalized()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("use"):
		GameManager.use_active_item(get_drop_position())
		return
	for i in range(GameManager.INVENTORY_SIZE):
		var action_name: String = "slot_%d" % (i + 1)
		if event.is_action_pressed(action_name):
			switch_to_slot(i)
			return
	if event.is_action_pressed("slot_next"):
		GameManager.switch_next()
	elif event.is_action_pressed("slot_prev"):
		GameManager.switch_prev()

func get_drop_position() -> Vector2:
	return global_position + facing_direction * drop_distance

func switch_to_slot(slot: int) -> void:
	GameManager.switch_slot(slot)

func _on_pickup_zone_area_entered(area: Area2D):
	if area.has_method("pick_up") and area.current_state == area.State.PICKUP:
		_items_in_range.append(area)
		GameManager.try_pickup.call_deferred(area)

func _on_pickup_zone_area_exited(area: Area2D):
	if not "zone_type" in area:
		_items_in_range.erase(area)
