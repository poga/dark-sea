extends Area2D

signal died(monster_type: String, position: Vector2)
signal damage_taken(amount: float, pos: Vector2)

@export var monster_type: String = "default"
@export var hp: float = 30.0
@export var speed: float = 50.0
@export var despawn_x: float = -500.0

func _physics_process(delta: float) -> void:
	global_position.x -= speed * delta
	if global_position.x < despawn_x:
		queue_free()

func take_damage(amount: float) -> void:
	hp -= amount
	damage_taken.emit(amount, global_position)
	if hp <= 0:
		died.emit(monster_type, global_position)
		queue_free()
