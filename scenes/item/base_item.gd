extends Area2D

signal picked_up
signal activated
signal deactivated

enum State { PICKUP, ACTIVE, INVENTORY }
enum UseResult { NOTHING, KEEP, CONSUME, PLACE }

@export var item_name: String = "Item"
@export var inventory_icon: Texture2D
@export var swing_duration: float = 0.3
@export var swing_angle: float = 45.0

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
