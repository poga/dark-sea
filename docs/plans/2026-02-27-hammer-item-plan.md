# Hammer Item Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a reusable hammer item that deals 100 area damage at the click position.

**Architecture:** Extends `base_item.gd` directly. Uses a physics space query (CircleShape2D on collision mask 4) to find monsters at the target position and calls `take_damage()` on each. Returns `UseResult.KEEP` so it stays in inventory.

**Tech Stack:** GDScript, Godot 4 physics queries, GUT testing framework.

---

### Task 1: Create hammer_item.gd script

**Files:**
- Create: `scenes/item/hammer_item.gd`
- Reference: `scenes/item/base_item.gd` (base class), `scenes/item/turret_item.gd:26-44` (physics query pattern)

**Step 1: Create the script**

```gdscript
extends "res://scenes/item/base_item.gd"

@export var damage: float = 100.0
@export var bonk_radius: float = 80.0

var _bonk_shape: CircleShape2D

func _ready():
	super._ready()
	_bonk_shape = CircleShape2D.new()
	_bonk_shape.radius = bonk_radius

func has_preview() -> bool:
	return true

func use(context: Dictionary) -> int:
	var target_pos: Vector2 = context.target_position
	if not is_inside_tree():
		return UseResult.NOTHING
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _bonk_shape
	query.transform = Transform2D(0, target_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 4
	var results: Array[Dictionary] = space_state.intersect_shape(query)
	for result in results:
		var collider = result["collider"]
		if collider.has_method("take_damage"):
			collider.take_damage(damage)
	return UseResult.KEEP
```

**Step 2: Validate**

Run: `just check`
Expected: Project validates successfully (no SCRIPT ERROR for hammer_item.gd). This will fail because the scene doesn't exist yet — that's expected. The script itself should parse without errors.

**Step 3: Commit**

```bash
git add scenes/item/hammer_item.gd
git commit -m "feat: add hammer_item.gd script extending base_item"
```

---

### Task 2: Create hammer_item.tscn scene

**Files:**
- Create: `scenes/item/hammer_item.tscn`
- Reference: `scenes/item/item.tscn` (base scene structure), `scenes/item/aoe_item.tscn` (sibling example)

**Step 1: Create the scene file**

Follow the same structure as `item.tscn` but with:
- Script pointing to `hammer_item.gd`
- `item_name = "Hammer"`
- Orange modulate (`Color(1, 0.7, 0.2, 1)`) on PickupState sprite to visually distinguish from other items
- Purple modulate (`Color(0.7, 0.3, 1, 1)`) on InventoryState sprite
- ActiveState still needed for `_update_state_visuals()` in base_item (it references `$ActiveState`) but it can be minimal — just a Node2D with Label, no special children

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/item/hammer_item.gd" id="1"]
[ext_resource type="Texture2D" path="res://icon.svg" id="2"]

[sub_resource type="CircleShape2D" id="SubResource_1"]
radius = 20.0

[node name="Item" type="Area2D"]
script = ExtResource("1")
item_name = "Hammer"
inventory_icon = ExtResource("2")

[node name="PickupState" type="Node2D" parent="."]

[node name="Sprite2D" type="Sprite2D" parent="PickupState"]
texture = ExtResource("2")
scale = Vector2(0.5, 0.5)
modulate = Color(1, 0.7, 0.2, 1)

[node name="Label" type="Label" parent="PickupState"]
offset_left = -40.0
offset_top = -55.0
offset_right = 40.0
offset_bottom = -35.0
horizontal_alignment = 1
text = "Hammer"

[node name="ActiveState" type="Node2D" parent="."]
visible = false

[node name="Sprite2D" type="Sprite2D" parent="ActiveState"]
texture = ExtResource("2")
scale = Vector2(0.5, 0.5)

[node name="Label" type="Label" parent="ActiveState"]
offset_left = -40.0
offset_top = -55.0
offset_right = 40.0
offset_bottom = -35.0
horizontal_alignment = 1
text = "Hammer"

[node name="InventoryState" type="Node2D" parent="."]
visible = false

[node name="Sprite2D" type="Sprite2D" parent="InventoryState"]
texture = ExtResource("2")
scale = Vector2(0.3, 0.3)
modulate = Color(0.7, 0.3, 1, 1)

[node name="Label" type="Label" parent="InventoryState"]
offset_left = -40.0
offset_top = -45.0
offset_right = 40.0
offset_bottom = -25.0
horizontal_alignment = 1
text = "Hammer"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SubResource_1")
```

**Step 2: Validate**

Run: `just check`
Expected: Project validates successfully

**Step 3: Commit**

```bash
git add scenes/item/hammer_item.tscn
git commit -m "feat: add hammer_item.tscn scene"
```

---

### Task 3: Add hammer to item spawner

**Files:**
- Modify: `scenes/game/item_spawner.gd:16-19` (item_pool array)

**Step 1: Add hammer to the item pool**

In `item_spawner.gd`, add the hammer entry to the `item_pool` array:

```gdscript
var item_pool: Array[Dictionary] = [
	{ "scene": preload("res://scenes/item/turret_item.tscn"), "weight": 3 },
	{ "scene": preload("res://scenes/item/aoe_item.tscn"), "weight": 1 },
	{ "scene": preload("res://scenes/item/hammer_item.tscn"), "weight": 2 },
]
```

Weight 2 makes the hammer moderately common — less than turrets (3), more than AOE (1).

**Step 2: Validate**

Run: `just check`
Expected: Project validates successfully

**Step 3: Commit**

```bash
git add scenes/game/item_spawner.gd
git commit -m "feat: add hammer to item spawner pool with weight 2"
```

---

### Task 4: Manual verification

**Step 1: Run the game and verify**

Run the game in the Godot editor. Verify:
- Hammer items spawn during the day phase
- Picking up a hammer shows it in the toolbar with purple tint
- Clicking to use the hammer on empty ground does nothing visible (no monsters)
- Using the hammer on a group of monsters deals 100 damage to each within the radius
- The hammer stays in inventory after use (reusable)
- The drop preview circle shows at cursor position

**Step 2: Final commit if any adjustments needed**

If adjustments were made during verification, commit them.
