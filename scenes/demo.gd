extends Node2D

const BasicFloatLabel = preload("res://scenes/NumberLabel/basic_float_label.tscn")
const SpecialFloatLabel = preload("res://scenes/NumberLabel/special_float_label.tscn")
const ChannelingLabel = preload("res://scenes/channeling_label.tscn")

const TICK_INTERVAL: float = 0.1
const BASIC_DAMAGE_MIN: int = 19
const BASIC_DAMAGE_MAX: int = 25
const SPECIAL_DAMAGE_MIN: int = 130
const SPECIAL_DAMAGE_MAX: int = 160
const SPECIAL_PROC_CHANCE: float = 0.1

var is_holding_target: bool = false
var tick_accumulator: float = 0.0

func _process(delta: float) -> void:
	if is_holding_target:
		tick_accumulator += delta
		while tick_accumulator >= TICK_INTERVAL:
			tick_accumulator -= TICK_INTERVAL
			_deal_damage_tick()

func _deal_damage_tick() -> void:
	var basic_damage: int = randi_range(BASIC_DAMAGE_MIN, BASIC_DAMAGE_MAX)
	$DamageDisplay.show_basic(basic_damage)

	if randf() < SPECIAL_PROC_CHANCE:
		var special_damage: int = randi_range(SPECIAL_DAMAGE_MIN, SPECIAL_DAMAGE_MAX)
		$DamageDisplay.show_special(special_damage)

func _on_dummy_target_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_holding_target = event.pressed
		if not event.pressed:
			tick_accumulator = 0.0

func _on_dummy_target_mouse_exited() -> void:
	is_holding_target = false
	tick_accumulator = 0.0

func _on_plus_one_pressed():
	$NumberLabel.add(1)
	$PopNumberLabel.add(1)


func _on_plus_hundred_pressed():
	$NumberLabel.add(100)
	$PopNumberLabel.add(100)


func _on_spawn_float_pressed():
	var label: Label = BasicFloatLabel.instantiate()
	label.text = str(randi_range(1, 99))
	label.position = $SpawnFloat.position + $SpawnFloat.size / 2
	add_child(label)


func _on_spawn_special_pressed():
	var label: Label = SpecialFloatLabel.instantiate()
	label.text = str(randi_range(100, 999))
	label.position = $SpawnSpecial.position + $SpawnSpecial.size / 2
	add_child(label)


func _on_spawn_channel_pressed():
	var channel: Node2D = ChannelingLabel.instantiate()
	channel.text = $ChannelTextInput.text
	channel.position = Vector2(270, 350)
	add_child(channel)
	channel.start()
