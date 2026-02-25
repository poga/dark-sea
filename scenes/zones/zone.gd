extends Area2D

enum ZoneType { TOWER, SEA }

@export var zone_type: ZoneType = ZoneType.TOWER
@export var zone_color: Color = Color(0.5, 0.5, 0.5, 0.2)
@export var zone_width: float = 200.0
@export var zone_height: float = 800.0

func _ready() -> void:
	$ColorRect.color = zone_color
	$ColorRect.size = Vector2(zone_width, zone_height)
	$ColorRect.position = Vector2(-zone_width / 2, -zone_height / 2)
	$CollisionShape2D.shape = RectangleShape2D.new()
	$CollisionShape2D.shape.size = Vector2(zone_width, zone_height)
