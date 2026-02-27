extends CharacterBody2D

@export var speed: float = 200.0
@export var camera_smoothing_speed: float = 5.0
@export var drop_distance: float = 80.0

var facing_direction: Vector2 = Vector2.RIGHT
var _items_in_range: Array[Area2D] = []

func _ready():
	GameManager.register_player(self)
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
	var item: Area2D = GameManager.get_active_item()
	if item and item.has_preview():
		var context: Dictionary = {"target_position": get_drop_position(), "player": self}
		preview.visible = true
		preview.global_position = item.get_preview_position(context)
		preview.update_state(item.can_use(context))
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
		GameManager.try_pickup(area)

func _on_pickup_zone_area_exited(area: Area2D):
	if not "zone_type" in area:
		_items_in_range.erase(area)
