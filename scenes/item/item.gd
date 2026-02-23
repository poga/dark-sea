extends Area2D

signal picked_up_as_item
signal picked_up_as_turret
signal placed_as_turret

enum State { PICKUP, TURRET }

@export var item_name: String = "Item"

var current_state: State = State.PICKUP

func _ready():
	$PickupState/Label.text = item_name
	$TurretState/Label.text = item_name
	_update_state_visuals()

func pick_up():
	if current_state == State.PICKUP:
		picked_up_as_item.emit()
	else:
		picked_up_as_turret.emit()
	current_state = State.PICKUP
	_update_state_visuals()

func drop():
	current_state = State.TURRET
	_update_state_visuals()
	placed_as_turret.emit()

func drop_as_pickup() -> void:
	current_state = State.PICKUP
	_update_state_visuals()

func _update_state_visuals():
	$PickupState.visible = current_state == State.PICKUP
	$TurretState.visible = current_state == State.TURRET
