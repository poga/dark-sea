# Tide Z-Order Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the Tide ColorRect rendering order so it appears above terrain but below Player, Monsters, and DamageNumbers. Dropped items/gold appear submerged.

**Architecture:** Use Godot's `z_index` property on scene nodes. Move Tide earlier in the scene tree and assign z_index layers: terrain/items at 0, Tide at 1, active entities at 2.

**Tech Stack:** Godot 4, `.tscn` scene file edits only.

---

### Task 1: Move Tide node and set z_index values in main.tscn

**Files:**
- Modify: `scenes/game/main.tscn`

**Step 1: Move the Tide node block from after UI to after Zones**

In `scenes/game/main.tscn`, move the Tide node declaration (currently at the end of file, after the UI section) to immediately after the `SeaZone` node and before the `Player` node. Add `z_index = 1`.

The Tide block to move:
```
[node name="Tide" type="ColorRect" parent="." unique_id=1481333432]
offset_left = 100.0
offset_top = -400.0
offset_right = 504.0
offset_bottom = 393.0
color = Color(0, 0.5921569, 0.7764706, 0.5803922)
script = ExtResource("15")
```

After moving, add `z_index = 1` to the Tide node properties.

**Step 2: Set z_index = 2 on Player node**

Change:
```
[node name="Player" parent="." unique_id=1427541742 instance=ExtResource("1")]
```
To:
```
[node name="Player" parent="." unique_id=1427541742 instance=ExtResource("1")]
z_index = 2
```

**Step 3: Set z_index = 2 on Monsters node**

Change:
```
[node name="Monsters" type="Node2D" parent="." unique_id=1315256508]
```
To:
```
[node name="Monsters" type="Node2D" parent="." unique_id=1315256508]
z_index = 2
```

**Step 4: Set z_index = 2 on DamageNumbers node**

Change:
```
[node name="DamageNumbers" type="Node2D" parent="."]
script = ExtResource("16")
```
To:
```
[node name="DamageNumbers" type="Node2D" parent="."]
z_index = 2
script = ExtResource("16")
```

**Step 5: Validate**

Run: `just check`
Expected: No parse errors.

**Step 6: Commit**

```bash
git add scenes/game/main.tscn
git commit -m "fix: tide z-order renders above terrain but below active entities"
```

### Task 2: Manual verification

**Verify in Godot editor:**
1. Open the project and run the game scene
2. Confirm Tide ColorRect renders above the zone backgrounds (blue/green tints)
3. Confirm Player character renders above the Tide
4. Confirm Monsters render above the Tide
5. Confirm DamageNumbers render above the Tide
6. Confirm dropped items/gold on the ground appear submerged (below Tide)
7. Confirm UI (toolbar, phase label, gold count) renders above everything
