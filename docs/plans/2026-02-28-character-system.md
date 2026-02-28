# Character System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a data-driven character system with JSON-defined characters, unlock persistence, character selection screen, and main menu flow.

**Architecture:** Characters defined in `data/characters.json`. GameManager loads character data, manages selection/unlocks, and applies stats at game start. New menu scenes handle flow: main_menu -> character_select -> game. Player scene reads character data from GameManager on `_ready()`.

**Tech Stack:** Godot 4.6, GDScript, GUT test framework, JSON data files

---

### Task 1: Create characters.json data file

**Files:**
- Create: `data/characters.json`

**Step 1: Create the character data file**

```json
{
  "default": {
    "name": "Castaway",
    "sprite": "res://icon.svg",
    "stats": {
      "speed": 200.0
    },
    "starting_items": [],
    "starting_resources": {},
    "locked": false
  }
}
```

Notes:
- At least one character MUST have `"locked": false` — this is the starter character
- Uses `icon.svg` as placeholder sprite (same as current player)
- Stats match current player defaults so behavior is unchanged
- More characters can be added later by designers editing this file

**Step 2: Run validation**

Run: `just check`
Expected: Project validates successfully (JSON file is just data, no script changes yet)

**Step 3: Commit**

```bash
git add data/characters.json
git commit -m "feat: add characters.json with default character"
```

---

### Task 2: GameManager character loading and selection

**Files:**
- Modify: `core/game_manager.gd`
- Test: `core/tests/test_game_manager.gd`

**Step 1: Write failing tests for character loading**

Add to `core/tests/test_game_manager.gd`:

```gdscript
func test_load_characters_populates_characters_dict():
	GameManager.load_characters()
	assert_gt(GameManager.characters.size(), 0, "Should load at least one character")

func test_load_characters_has_default():
	GameManager.load_characters()
	assert_true(GameManager.characters.has("default"), "Should have default character")

func test_load_characters_default_has_name():
	GameManager.load_characters()
	var char_data: Dictionary = GameManager.characters["default"]
	assert_eq(char_data["name"], "Castaway")

func test_set_character_stores_selection():
	GameManager.load_characters()
	GameManager.set_character("default")
	assert_eq(GameManager.selected_character, "default")

func test_get_character_returns_data():
	GameManager.load_characters()
	GameManager.set_character("default")
	var data: Dictionary = GameManager.get_character()
	assert_eq(data["name"], "Castaway")

func test_set_character_emits_signal():
	GameManager.load_characters()
	watch_signals(GameManager)
	GameManager.set_character("default")
	assert_signal_emitted_with_parameters(GameManager, "character_selected", ["default"])

func test_get_character_returns_empty_when_none_selected():
	GameManager.selected_character = ""
	var data: Dictionary = GameManager.get_character()
	assert_eq(data.size(), 0)
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `load_characters`, `set_character`, `get_character`, `selected_character`, `character_selected` don't exist yet

**Step 3: Implement character loading in GameManager**

Add to `core/game_manager.gd`:

New signal (add with other signals at top):
```gdscript
signal character_selected(id: String)
```

New properties (add after existing vars):
```gdscript
var characters: Dictionary = {}
var selected_character: String = ""
```

New constant:
```gdscript
const CHARACTERS_PATH: String = "res://data/characters.json"
```

New methods (add after resource methods, before inventory section):
```gdscript
# --- Character management ---

func load_characters() -> void:
	var file := FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
	if file == null:
		push_error("GameManager: Could not open %s" % CHARACTERS_PATH)
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		push_error("GameManager: JSON parse error in %s: %s" % [CHARACTERS_PATH, json.get_error_message()])
		return
	characters = json.data

func set_character(id: String) -> void:
	if not characters.has(id):
		push_error("GameManager: Unknown character '%s'" % id)
		return
	selected_character = id
	character_selected.emit(id)

func get_character() -> Dictionary:
	if selected_character == "" or not characters.has(selected_character):
		return {}
	return characters[selected_character]
```

Also update `_ready()` to call `load_characters()`:
```gdscript
func _ready() -> void:
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	_phase_timer.timeout.connect(_on_phase_timer_timeout)
	add_child(_phase_timer)
	inventory.resize(INVENTORY_SIZE)
	inventory.fill(null)
	load_characters()
```

**Step 4: Update `before_each` in tests to reset character state**

Add to the existing `before_each()` in `core/tests/test_game_manager.gd`:
```gdscript
func before_each() -> void:
	GameManager.gold = 0
	GameManager.resources = {}
	GameManager.selected_character = ""
```

**Step 5: Run tests to verify they pass**

Run: `just test`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add core/game_manager.gd core/tests/test_game_manager.gd
git commit -m "feat: add character loading and selection to GameManager"
```

---

### Task 3: Unlock persistence

**Files:**
- Modify: `core/game_manager.gd`
- Test: `core/tests/test_game_manager.gd`

**Step 1: Write failing tests for unlock system**

Add to `core/tests/test_game_manager.gd`:

```gdscript
func test_default_character_is_unlocked():
	GameManager.load_characters()
	assert_true(GameManager.is_character_unlocked("default"))

func test_locked_character_is_not_unlocked():
	# Temporarily add a locked character to test
	GameManager.characters["locked_test"] = {"name": "Test", "locked": true}
	assert_false(GameManager.is_character_unlocked("locked_test"))

func test_unlock_character_makes_it_unlocked():
	GameManager.characters["locked_test"] = {"name": "Test", "locked": true}
	GameManager.unlock_character("locked_test")
	assert_true(GameManager.is_character_unlocked("locked_test"))

func test_unlock_character_emits_signal():
	GameManager.characters["locked_test"] = {"name": "Test", "locked": true}
	watch_signals(GameManager)
	GameManager.unlock_character("locked_test")
	assert_signal_emitted_with_parameters(GameManager, "character_unlocked", ["locked_test"])

func test_get_unlocked_characters_returns_unlocked_only():
	GameManager.load_characters()
	var unlocked: Array = GameManager.get_unlocked_characters()
	for id: String in unlocked:
		assert_true(GameManager.is_character_unlocked(id))
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `is_character_unlocked`, `unlock_character`, `character_unlocked`, `get_unlocked_characters` don't exist

**Step 3: Implement unlock system in GameManager**

Add new signal (with other signals):
```gdscript
signal character_unlocked(id: String)
```

Add new property:
```gdscript
var _unlocked_overrides: Array[String] = []
```

Add constant:
```gdscript
const SAVE_PATH: String = "user://save_data.json"
```

Add methods after `get_character()`:
```gdscript
func is_character_unlocked(id: String) -> bool:
	if _unlocked_overrides.has(id):
		return true
	if not characters.has(id):
		return false
	return not characters[id].get("locked", false)

func unlock_character(id: String) -> void:
	if not _unlocked_overrides.has(id):
		_unlocked_overrides.append(id)
		_save_unlocks()
	character_unlocked.emit(id)

func get_unlocked_characters() -> Array:
	var result: Array = []
	for id: String in characters:
		if is_character_unlocked(id):
			result.append(id)
	return result

func _save_unlocks() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameManager: Could not write %s" % SAVE_PATH)
		return
	var data: Dictionary = {"unlocked_characters": _unlocked_overrides}
	file.store_string(JSON.stringify(data, "\t"))

func _load_unlocks() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		return
	var data: Dictionary = json.data
	if data.has("unlocked_characters"):
		_unlocked_overrides.assign(data["unlocked_characters"])
```

Update `load_characters()` to also load unlocks:
```gdscript
func load_characters() -> void:
	var file := FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
	if file == null:
		push_error("GameManager: Could not open %s" % CHARACTERS_PATH)
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		push_error("GameManager: JSON parse error in %s: %s" % [CHARACTERS_PATH, json.get_error_message()])
		return
	characters = json.data
	_load_unlocks()
```

Update `before_each` in tests to also reset unlock state:
```gdscript
func before_each() -> void:
	GameManager.gold = 0
	GameManager.resources = {}
	GameManager.selected_character = ""
	GameManager._unlocked_overrides = []
```

**Step 4: Run tests to verify they pass**

Run: `just test`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add core/game_manager.gd core/tests/test_game_manager.gd
git commit -m "feat: add character unlock persistence with JSON save"
```

---

### Task 4: Apply character stats to player

**Files:**
- Modify: `scenes/player/player.gd`
- Modify: `scenes/player/player.tscn` (only if needed)

**Step 1: Modify player.gd to apply character data on ready**

Update `_ready()` in `scenes/player/player.gd`:

```gdscript
func _ready():
	GameManager.register_player(self)
	_apply_character_data()
	$Camera2D.position_smoothing_speed = camera_smoothing_speed
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
```

Notes:
- If no character is selected (e.g., running main.tscn directly for testing), defaults from `@export` vars are used — no change in behavior
- Stats are applied before anything else in `_ready()`
- Only overrides stats that exist in the character data, keeping `@export` defaults as fallback

**Step 2: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 3: Commit**

```bash
git add scenes/player/player.gd
git commit -m "feat: player applies character stats and sprite on ready"
```

---

### Task 5: Apply starting items and resources at game start

**Files:**
- Modify: `core/game_manager.gd`
- Modify: `scenes/game/main.gd`
- Test: `core/tests/test_game_manager.gd`

**Step 1: Write failing test for apply_character_loadout**

Add to `core/tests/test_game_manager.gd`:

```gdscript
func test_apply_character_loadout_sets_resources():
	GameManager.load_characters()
	GameManager.characters["test_char"] = {
		"name": "Test",
		"starting_items": [],
		"starting_resources": {"gold": 10, "bones": 5},
		"locked": false,
	}
	GameManager.set_character("test_char")
	GameManager.apply_character_loadout()
	assert_eq(GameManager.get_resource("gold"), 10)
	assert_eq(GameManager.get_resource("bones"), 5)

func test_apply_character_loadout_does_nothing_when_no_character():
	GameManager.selected_character = ""
	GameManager.apply_character_loadout()
	assert_eq(GameManager.get_resource("gold"), 0)
```

**Step 2: Run tests to verify they fail**

Run: `just test`
Expected: FAIL — `apply_character_loadout` doesn't exist

**Step 3: Implement apply_character_loadout**

Add method to `core/game_manager.gd` after `get_unlocked_characters()`:

```gdscript
func apply_character_loadout() -> void:
	var data: Dictionary = get_character()
	if data.is_empty():
		return
	# Apply starting resources
	var starting_resources: Dictionary = data.get("starting_resources", {})
	for type: String in starting_resources:
		add_resource(type, int(starting_resources[type]))
	# Apply starting items
	var starting_items: Array = data.get("starting_items", [])
	for item_path: String in starting_items:
		var scene: PackedScene = load(item_path)
		if scene == null:
			push_error("GameManager: Could not load item scene '%s'" % item_path)
			continue
		var item: Area2D = scene.instantiate()
		try_pickup(item)
```

**Step 4: Call apply_character_loadout in main.gd**

Update `scenes/game/main.gd`:

```gdscript
extends Node2D

func _ready() -> void:
	GameManager.apply_character_loadout()
	GameManager.start_cycle.call_deferred()
	%DebugSkipPhase.pressed.connect(GameManager.skip_to_next_phase)
```

**Step 5: Run tests to verify they pass**

Run: `just test`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add core/game_manager.gd core/tests/test_game_manager.gd scenes/game/main.gd
git commit -m "feat: apply character starting items and resources at game start"
```

---

### Task 6: Main menu scene

**Files:**
- Create: `scenes/menu/main_menu.gd`
- Create: `scenes/menu/main_menu.tscn`

**Step 1: Create main_menu.gd**

Create `scenes/menu/main_menu.gd`:

```gdscript
extends Control

func _ready() -> void:
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/character_select.tscn")
```

**Step 2: Create main_menu.tscn**

Create `scenes/menu/main_menu.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/menu/main_menu.gd" id="1"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -60.0
offset_right = 100.0
offset_bottom = 60.0
grow_horizontal = 2
grow_vertical = 2
alignment = 1

[node name="TitleLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
horizontal_alignment = 1
text = "Dark Sea"

[node name="PlayButton" type="Button" parent="VBoxContainer"]
layout_mode = 2
text = "Play"
```

**Step 3: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 4: Commit**

```bash
git add scenes/menu/main_menu.gd scenes/menu/main_menu.tscn
git commit -m "feat: add main menu scene with Play button"
```

---

### Task 7: Character select scene

**Files:**
- Create: `scenes/menu/character_select.gd`
- Create: `scenes/menu/character_select.tscn`

**Step 1: Create character_select.gd**

Create `scenes/menu/character_select.gd`:

```gdscript
extends Control

@onready var character_list: VBoxContainer = $ScrollContainer/CharacterList

func _ready() -> void:
	_build_character_list()
	$BackButton.pressed.connect(_on_back_pressed)

func _build_character_list() -> void:
	for id: String in GameManager.characters:
		var data: Dictionary = GameManager.characters[id]
		var unlocked: bool = GameManager.is_character_unlocked(id)
		var row: HBoxContainer = _create_character_row(id, data, unlocked)
		character_list.add_child(row)

func _create_character_row(id: String, data: Dictionary, unlocked: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Sprite preview
	var sprite := TextureRect.new()
	sprite.custom_minimum_size = Vector2(48, 48)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if data.has("sprite") and data["sprite"] != "":
		sprite.texture = load(data["sprite"])
	row.add_child(sprite)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = data.get("name", id)
	info.add_child(name_label)

	var stats_text: String = ""
	var stats: Dictionary = data.get("stats", {})
	for stat_name: String in stats:
		if stats_text != "":
			stats_text += " | "
		stats_text += "%s: %s" % [stat_name, str(stats[stat_name])]
	var items: Array = data.get("starting_items", [])
	if items.size() > 0:
		if stats_text != "":
			stats_text += " | "
		stats_text += "items: %d" % items.size()
	var resources: Dictionary = data.get("starting_resources", {})
	for res_name: String in resources:
		if stats_text != "":
			stats_text += " | "
		stats_text += "%s: %s" % [res_name, str(resources[res_name])]

	if stats_text != "":
		var stats_label := Label.new()
		stats_label.text = stats_text
		stats_label.add_theme_font_size_override("font_size", 12)
		info.add_child(stats_label)

	row.add_child(info)

	# Select button
	var button := Button.new()
	if unlocked:
		button.text = "Select"
		button.pressed.connect(_on_character_selected.bind(id))
	else:
		button.text = "Locked"
		button.disabled = true
	row.add_child(button)

	return row

func _on_character_selected(id: String) -> void:
	GameManager.set_character(id)
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
```

**Step 2: Create character_select.tscn**

Create `scenes/menu/character_select.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/menu/character_select.gd" id="1"]

[node name="CharacterSelect" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="MarginContainer" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
theme_override_constants/margin_left = 40
theme_override_constants/margin_top = 40
theme_override_constants/margin_right = 40
theme_override_constants/margin_bottom = 40

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer"]
layout_mode = 2

[node name="TitleLabel" type="Label" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
text = "Select Character"

[node name="ScrollContainer" type="ScrollContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 40.0
offset_top = 80.0
offset_right = -40.0
offset_bottom = -60.0

[node name="CharacterList" type="VBoxContainer" parent="ScrollContainer"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 8

[node name="BackButton" type="Button" parent="."]
layout_mode = 1
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -40.0
offset_top = -50.0
offset_right = 40.0
offset_bottom = -10.0
grow_horizontal = 2
grow_vertical = 0
text = "Back"
```

**Step 3: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 4: Commit**

```bash
git add scenes/menu/character_select.gd scenes/menu/character_select.tscn
git commit -m "feat: add character selection scene with list UI"
```

---

### Task 8: Wire up game flow and update run scene

**Files:**
- Modify: `project.godot`
- Modify: `core/game_manager.gd` (reset state on new game)

**Step 1: Add reset_for_new_game method to GameManager**

This ensures state is clean when starting a new game from the menu. Add to `core/game_manager.gd` before the inventory section:

```gdscript
func reset_for_new_game() -> void:
	gold = 0
	resources = {}
	reset_inventory()
```

**Step 2: Call reset in main.gd before applying loadout**

Update `scenes/game/main.gd`:

```gdscript
extends Node2D

func _ready() -> void:
	GameManager.reset_for_new_game()
	GameManager.apply_character_loadout()
	GameManager.start_cycle.call_deferred()
	%DebugSkipPhase.pressed.connect(GameManager.skip_to_next_phase)
```

**Step 3: Update project.godot run scene**

In `project.godot`, add under `[application]`:

```
run/main_scene="res://scenes/menu/main_menu.tscn"
```

**Step 4: Run validation**

Run: `just check`
Expected: Project validates successfully

**Step 5: Manual verification**

Run the game and verify:
1. Main menu appears with "Play" button
2. Clicking "Play" shows character select with the default "Castaway" character
3. Clicking "Select" starts the game
4. Player has correct stats and sprite
5. "Back" button returns to main menu

**Step 6: Commit**

```bash
git add project.godot core/game_manager.gd scenes/game/main.gd
git commit -m "feat: wire up main menu -> character select -> game flow"
```
