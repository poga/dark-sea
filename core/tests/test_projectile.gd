extends GutTest

var projectile: Area2D
var ProjectileScene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

func before_each():
	projectile = ProjectileScene.instantiate()
	add_child_autofree(projectile)

func test_moves_in_direction():
	projectile.direction = Vector2.RIGHT
	projectile.speed = 100.0
	var start_x: float = projectile.global_position.x
	projectile._physics_process(0.1)
	assert_gt(projectile.global_position.x, start_x)

func test_moves_with_speed():
	projectile.direction = Vector2(1, 0)
	projectile.speed = 200.0
	var start_pos: Vector2 = projectile.global_position
	projectile._physics_process(1.0)
	var moved: float = projectile.global_position.distance_to(start_pos)
	assert_almost_eq(moved, 200.0, 1.0)

func test_damage_property():
	projectile.damage = 15.0
	assert_eq(projectile.damage, 15.0)
