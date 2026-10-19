extends Node2D


func _ready() -> void:
	# This scene has no pollution model or trash manager: demonstration only.
	($Dirty as WaterVisuals).set_visual_target(1.0, true)
	($Midway as WaterVisuals).set_visual_target(0.5, true)
	($Clean as WaterVisuals).set_visual_target(0.0, true)
