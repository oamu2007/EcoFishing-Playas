extends Node2D

@onready var _ocean: Polygon2D = $Environment/Ocean
@onready var _rod: FishingRod = $Player/FishingRod


func _ready() -> void:
	# Derive world-space fishing bounds from the authored rectangular ocean.
	var bounds: Rect2 = Rect2(_ocean.to_global(_ocean.polygon[0]), Vector2.ZERO)
	for point: Vector2 in _ocean.polygon:
		bounds = bounds.expand(_ocean.to_global(point))
	_rod.water_bounds = bounds
