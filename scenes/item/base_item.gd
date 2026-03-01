extends Area2D

signal picked_up
signal activated
signal deactivated

enum State { PICKUP, ACTIVE, INVENTORY }
enum UseResult { NOTHING, KEEP, CONSUME, PLACE }

@export var item_name: String = "Item"
@export var inventory_icon: Texture2D
@export var swing_duration: float = 0.1
@export var swing_distance: float = 60.0

var is_swinging: bool = false
var _swing_tween: Tween

var current_state: State = State.PICKUP

func _ready():
	$PickupState/Label.text = item_name
	$ActiveState/Label.text = item_name
	$InventoryState/Label.text = item_name
	_update_state_visuals()

func pick_up():
	if current_state == State.ACTIVE:
		deactivated.emit()
	else:
		picked_up.emit()
	current_state = State.PICKUP
	_update_state_visuals()

func activate() -> void:
	current_state = State.ACTIVE
	_update_state_visuals()
	activated.emit()

## Backward compatibility — use activate() for new code
func drop() -> void:
	activate()

func drop_as_pickup() -> void:
	current_state = State.PICKUP
	_update_state_visuals()

func store_in_inventory() -> void:
	current_state = State.INVENTORY
	_update_state_visuals()

# --- Virtual methods: override in item subclasses ---

func can_use(_context: Dictionary) -> bool:
	return true

func use(_context: Dictionary) -> int:
	return UseResult.CONSUME

func has_preview() -> bool:
	return false

func get_preview_position(context: Dictionary) -> Vector2:
	return context.target_position

# --- Internal ---

func _update_state_visuals():
	$PickupState.visible = current_state == State.PICKUP
	$ActiveState.visible = current_state == State.ACTIVE
	$InventoryState.visible = current_state == State.INVENTORY

# --- Swing animation ---

func play_swing(facing: Vector2, on_impact: Callable) -> void:
	is_swinging = true
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	var side: float = 1.0 if facing.x >= 0 else -1.0
	var target_pos: Vector2 = Vector2(side * swing_distance, swing_distance)
	_swing_tween.tween_property(self, "position", target_pos, swing_duration).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_callback(func(): position = Vector2.ZERO)
	_swing_tween.tween_callback(on_impact)
	_swing_tween.tween_callback(func(): is_swinging = false)
