extends Node2D

var _size: Vector2 = Vector2(760, 900)


func configure_size(size: Vector2) -> void:
	_size = size
	queue_redraw()


func _draw() -> void:
	# Cached CanvasItem draw commands: regenerated only when the size changes.
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.20, 0.43, 0.43))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 57123
	for index: int in range(13):
		var center: Vector2 = Vector2(rng.randf_range(0.10, 0.92), rng.randf_range(0.08, 0.92)) * _size
		var radii: Vector2 = Vector2(rng.randf_range(36.0, 85.0), rng.randf_range(22.0, 47.0))
		center = center.clamp(radii * 1.1, _size - radii * 1.1)
		var polygon: PackedVector2Array = PackedVector2Array()
		for vertex: int in range(48):
			var angle: float = TAU * vertex / 48.0
			var organic: float = 1.0 + 0.09 * sin(angle * 3.0 + index)
			polygon.append(center + Vector2(cos(angle), sin(angle)) * radii * organic)
		draw_colored_polygon(polygon, Color(0.42, 0.55, 0.43, 0.62))
	for index: int in range(18):
		var center: Vector2 = Vector2(rng.randf_range(0.08, 0.95), rng.randf_range(0.04, 0.96)) * _size
		var radius: float = rng.randf_range(7.0, 17.0)
		var polygon: PackedVector2Array = PackedVector2Array()
		for vertex: int in range(12):
			var angle: float = TAU * vertex / 12.0
			polygon.append(center + Vector2(cos(angle), sin(angle) * 0.65) * radius)
		draw_colored_polygon(polygon, Color(0.12, 0.29, 0.30, 0.7))
