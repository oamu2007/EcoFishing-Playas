class_name FishingShack
extends Node2D

@export_range(1.0, 160.0, 1.0) var interaction_radius: float = 64.0

@onready var _prompt: Label = $InteractionPrompt


func is_near(point: Vector2) -> bool:
	return global_position.distance_squared_to(point) <= interaction_radius * interaction_radius


func set_prompt_visible(value: bool) -> void:
	_prompt.visible = value
