# Toolbar Slot Swap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow players to rearrange toolbar items by clicking slots (Stardew Valley style: click to pick up, click to place/swap, click outside to drop).

**Architecture:** Toolbar-owned interaction. Toolbar handles click state machine and cursor visual. GameManager gets `swap_slots()` and `drop_item_from_slot()` methods. Player's drop distance derived from pickup radius.

**Tech Stack:** GDScript, Godot 4 signals, GUT test framework.

---

### Task 1: Player drop distance from pickup radius

**Files:**
- Modify: `scenes/player/player.gd:4,69-70`

**Step 1: Change drop_distance to drop_margin**

Replace the `@export var drop_distance` with `drop_margin` and update `get_drop_position()` to derive distance from PickupZone radius.

```gdscript
# line 4: replace
@export var drop_margin: float = 30.0

# lines 69-70: replace get_drop_position
func get_drop_position() -> Vector2:
	var radius: float = $PickupZone/CollisionShape2D.shape.radius
	return global_position + facing_direction * (radius + drop_margin)
```

**Step 2: Run validation**

Run: `just check`
Expected: No errors.

**Step 3: Commit**

```
git add scenes/player/player.gd
git commit -m "refactor: derive drop distance from pickup zone radius"
```

---

### Task 2: GameManager.swap_slots() with tests

**Files:**
- Modify: `core/game_manager.gd` (add `swap_slots` method)
- Modify: `core/tests/test_inventory.gd` (add swap tests)

**Step 1: Write failing tests**

Add to `core/tests/test_inventory.gd`:

```gdscript
# --- Swap slots ---

func test_swap_slots_swaps_items():
	var item_a: Area2D = _make_item()
	var item_b: Area2D = _make_item()
	GameManager.try_pickup(item_a)
	GameManager.try_pickup(item_b)
	GameManager.swap_slots(0, 1)
	assert_eq(GameManager.inventory[0], item_b)
	assert_eq(GameManager.inventory[1], item_a)

func test_swap_slots_emits_inventory_changed_for_both():
	var item_a: Area2D = _make_item()
	var item_b: Area2D = _make_item()
	GameManager.try_pickup(item_a)
	GameManager.try_pickup(item_b)
	watch_signals(GameManager)
	GameManager.swap_slots(0, 1)
	assert_signal_emitted_with_parameters(GameManager, "inventory_changed", [0, item_b])

func test_swap_slots_moves_to_empty():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	GameManager.swap_slots(0, 3)
	assert_null(GameManager.inventory[0])
	assert_eq(GameManager.inventory[3], item)

func test_swap_slots_with_active_slot_reparents():
	var item_a: Area2D = _make_item()
	var item_b: Area2D = _make_item()
	GameManager.try_pickup(item_a)
	GameManager.try_pickup(item_b)
	# active_slot is 0, swap 0 and 1
	GameManager.swap_slots(0, 1)
	# item_b should now be in HoldPosition (it moved to active slot 0)
	assert_eq(player.get_node("HoldPosition").get_child_count(), 1)
	assert_eq(player.get_node("HoldPosition").get_child(0), item_b)

func test_swap_same_slot_is_noop():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	watch_signals(GameManager)
	GameManager.swap_slots(0, 0)
	assert_signal_not_emitted(GameManager, "inventory_changed")
	assert_eq(GameManager.inventory[0], item)
```

**Step 2: Run tests to verify they fail**

Run: `just check && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gtest=test_inventory.gd`
Expected: FAIL — `swap_slots` method not found.

**Step 3: Implement swap_slots**

Add to `core/game_manager.gd` after `switch_prev()` (around line 240):

```gdscript
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
```

**Step 4: Run tests to verify they pass**

Run: `just check && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gtest=test_inventory.gd`
Expected: All PASS.

**Step 5: Commit**

```
git add core/game_manager.gd core/tests/test_inventory.gd
git commit -m "feat: add GameManager.swap_slots with tests"
```

---

### Task 3: GameManager.drop_item_from_slot() with tests

**Files:**
- Modify: `core/game_manager.gd` (add `drop_item_from_slot` method)
- Modify: `core/tests/test_inventory.gd` (add drop tests)

**Step 1: Write failing tests**

Add to `core/tests/test_inventory.gd`:

```gdscript
# --- Drop item from slot ---

func test_drop_item_from_slot_removes_from_inventory():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	GameManager.drop_item_from_slot(0, Vector2(200, 0))
	assert_null(GameManager.inventory[0])

func test_drop_item_from_slot_emits_inventory_changed():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	watch_signals(GameManager)
	GameManager.drop_item_from_slot(0, Vector2(200, 0))
	assert_signal_emitted_with_parameters(GameManager, "inventory_changed", [0, null])

func test_drop_item_from_slot_sets_pickup_state():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	GameManager.drop_item_from_slot(0, Vector2(200, 0))
	assert_eq(item.current_state, item.State.PICKUP)

func test_drop_item_from_slot_positions_item():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	GameManager.drop_item_from_slot(0, Vector2(200, 100))
	assert_eq(item.global_position, Vector2(200, 100))

func test_drop_item_from_slot_on_empty_is_noop():
	watch_signals(GameManager)
	GameManager.drop_item_from_slot(0, Vector2(200, 0))
	assert_signal_not_emitted(GameManager, "inventory_changed")

func test_drop_item_from_active_slot_removes_from_hold():
	var item: Area2D = _make_item()
	GameManager.try_pickup(item)
	GameManager.drop_item_from_slot(0, Vector2(200, 0))
	assert_eq(player.get_node("HoldPosition").get_child_count(), 0)
```

**Step 2: Run tests to verify they fail**

Run: `just check && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gtest=test_inventory.gd`
Expected: FAIL — `drop_item_from_slot` method not found.

**Step 3: Implement drop_item_from_slot**

Add to `core/game_manager.gd` after `swap_slots()`:

```gdscript
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
```

**Step 4: Run tests to verify they pass**

Run: `just check && godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://core/tests/ -gtest=test_inventory.gd`
Expected: All PASS.

**Step 5: Commit**

```
git add core/game_manager.gd core/tests/test_inventory.gd
git commit -m "feat: add GameManager.drop_item_from_slot with tests"
```

---

### Task 4: Toolbar click-to-swap interaction

**Files:**
- Modify: `scenes/ui/toolbar.gd` (add click handling, held state, cursor item)

**Step 1: Add held state and click handling to toolbar**

Rewrite `scenes/ui/toolbar.gd` to add the interaction state machine. Key changes:

1. Each slot's `PanelContainer` gets `mouse_filter = MOUSE_FILTER_STOP` and a `gui_input` connection
2. Track `held_slot: int = -1`
3. Add a `_cursor_icon: TextureRect` on a `CanvasLayer` that follows the mouse
4. Handle click logic: pick up, swap, cancel

```gdscript
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
```

**Step 2: Run validation**

Run: `just check`
Expected: No errors.

**Step 3: Commit**

```
git add scenes/ui/toolbar.gd
git commit -m "feat: add click-to-swap toolbar interaction with cursor follow"
```

---

### Task 5: Cancel hold on keyboard slot switch

**Files:**
- Modify: `scenes/ui/toolbar.gd` (cancel hold when active slot changes)

**Step 1: Add cancel on slot switch**

In `_on_active_slot_changed`, cancel any held item first:

```gdscript
func _on_active_slot_changed(_slot: int) -> void:
	if held_slot >= 0:
		_cancel_hold()
	_update_active_highlight()
```

**Step 2: Run validation**

Run: `just check`
Expected: No errors.

**Step 3: Commit**

```
git add scenes/ui/toolbar.gd
git commit -m "feat: cancel toolbar hold on keyboard slot switch"
```

---

### Task 6: Manual verification

Test the following scenarios in-game:

- [ ] Pick up item from slot → icon follows cursor, slot appears empty
- [ ] Click another occupied slot → items swap
- [ ] Click empty slot → item moves there
- [ ] Click same slot → cancels, item returns
- [ ] Click outside toolbar → item drops in world beyond pickup range
- [ ] Press ESC while holding → cancels
- [ ] Press 1-8 while holding → cancels hold, then switches slot
- [ ] Active slot involved in swap → held item in HoldPosition updates correctly
