extends Line2D

@export_range(4, 32) var segments: int = 14
@export_range(1.0, 30.0) var settling_speed: float = 12.0

var _slack: float = 0.0


func connect_endpoints(rod_tip: Vector2, hook_tip: Vector2) -> void:
	_slack = 0.0
	points = PackedVector2Array([to_local(rod_tip), to_local(hook_tip)])


func follow_endpoints(rod_tip: Vector2, hook_tip: Vector2, desired_slack: float, delta: float) -> void:
	_slack = lerpf(_slack, desired_slack, 1.0 - exp(-settling_speed * delta))
	var start: Vector2 = to_local(rod_tip)
	var finish: Vector2 = to_local(hook_tip)
	var sag: float = minf(_slack, start.distance_to(finish) * 0.40)
	var curve: PackedVector2Array = PackedVector2Array()
	curve.resize(segments + 1)
	curve[0] = start
	for index: int in range(1, segments):
		var portion: float = float(index) / segments
		curve[index] = start.lerp(finish, portion) + Vector2.DOWN * (4.0 * sag * portion * (1.0 - portion))
	curve[segments] = finish
	points = curve
