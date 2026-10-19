class_name FishingHook
extends Area2D

@onready var visual: Node2D = $Visual


func set_height(height: float) -> void:
	visual.position = Vector2.UP * height


func get_line_endpoint() -> Vector2:
	return visual.global_position


func get_collision_radius() -> float:
	var collider: CollisionShape2D = $CollisionShape2D
	var circle: CircleShape2D = collider.shape as CircleShape2D
	return circle.radius * maxf(absf(collider.global_scale.x), absf(collider.global_scale.y))
