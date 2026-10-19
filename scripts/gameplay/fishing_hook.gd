class_name FishingHook
extends Area2D

@onready var visual: Node2D = $Visual


func set_height(height: float) -> void:
	visual.position = Vector2.UP * height


func get_line_endpoint() -> Vector2:
	return visual.global_position
