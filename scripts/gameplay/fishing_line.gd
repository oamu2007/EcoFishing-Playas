extends Line2D


func connect_endpoints(rod_tip: Vector2, hook_tip: Vector2) -> void:
	points = PackedVector2Array([to_local(rod_tip), to_local(hook_tip)])
