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
