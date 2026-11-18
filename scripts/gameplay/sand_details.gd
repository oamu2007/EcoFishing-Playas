extends Node2D

# Detalles de la arena: piedritas, conchas y marcas de viento.
# Usa una semilla fija para que la playa siempre se vea igual.

const SEED: int = 2026
const AREA: Rect2 = Rect2(20, 20, 740, 860)
const PEBBLE_CLUSTERS: int = 10
const SHELL_COUNT: int = 12
const RIPPLE_COUNT: int = 18
const MIN_SPACING: float = 40.0
const MAX_TRIES: int = 30

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _used_points: Array[Vector2] = []
var _pebbles: Array[Dictionary] = []
var _shells: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = SEED
	for _i: int in range(RIPPLE_COUNT):
		_ripples.append(_make_ripple())
	for _i: int in range(PEBBLE_CLUSTERS):
		_make_pebble_cluster(_free_point())
	for _i: int in range(SHELL_COUNT):
		_shells.append(_make_shell(_free_point()))
	queue_redraw()


# Busca un punto que no quede pegado a los que ya usamos
func _free_point() -> Vector2:
	var point: Vector2 = Vector2.ZERO
	for _try: int in range(MAX_TRIES):
		point = Vector2(
			_rng.randf_range(AREA.position.x, AREA.end.x),
			_rng.randf_range(AREA.position.y, AREA.end.y)
		)
		var is_free: bool = true
		for other: Vector2 in _used_points:
			if point.distance_to(other) < MIN_SPACING:
				is_free = false
				break
		if is_free:
			break
	_used_points.append(point)
	return point


# Forma irregular: puntos en coordenadas polares (ángulo + radio)
func _make_blob(radius: float, stretch: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var sides: int = 7
	for i: int in range(sides):
		var angle: float = TAU * float(i) / float(sides)
		var r: float = radius * _rng.randf_range(0.75, 1.0)
		points.append(Vector2(cos(angle) * r * stretch, sin(angle) * r))
	return points


func _make_pebble_cluster(center: Vector2) -> void:
	var count: int = _rng.randi_range(2, 4)
	for _n: int in range(count):
		var tone: float = _rng.randf_range(0.42, 0.62)
		_pebbles.append({
			"position": center + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-10.0, 10.0)),
			"angle": _rng.randf_range(0.0, TAU),
			"shape": _make_blob(_rng.randf_range(3.0, 7.0), _rng.randf_range(1.0, 1.5)),
			"color": Color(tone, tone * 0.94, tone * 0.82),
		})


# Concha: un abanico (origen + puntos sobre un arco)
func _make_shell(center: Vector2) -> Dictionary:
	var radius: float = _rng.randf_range(6.0, 9.0)
	var fan: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for step: int in range(7):
		var angle: float = lerpf(-1.0, 1.0, float(step) / 6.0)
		fan.append(Vector2(cos(angle), sin(angle)) * radius)
	var pink: float = _rng.randf()
	return {
		"position": center,
		"angle": _rng.randf_range(0.0, TAU),
		"shape": fan,
		"color": Color(0.96, 0.88, 0.80).lerp(Color(0.95, 0.72, 0.68), pink),
	}


func _make_ripple() -> Dictionary:
	return {
		"position": Vector2(
			_rng.randf_range(AREA.position.x, AREA.end.x),
			_rng.randf_range(AREA.position.y, AREA.end.y)
		),
		"radius": _rng.randf_range(18.0, 46.0),
		"start": _rng.randf_range(0.0, TAU),
		"length": _rng.randf_range(0.6, 1.1),
	}


func _draw() -> void:
	# Marcas de viento: arcos con una línea clara y una oscura (da relieve)
	for ripple: Dictionary in _ripples:
		var center: Vector2 = ripple["position"]
		var radius: float = ripple["radius"]
		var start: float = ripple["start"]
		var arc_length: float = ripple["length"]
		draw_arc(center + Vector2(1, 1), radius, start, start + arc_length, 16, Color(1.0, 0.96, 0.78, 0.35), 1.5, true)
		draw_arc(center, radius, start, start + arc_length, 16, Color(0.55, 0.42, 0.22, 0.30), 1.5, true)

	# Piedritas: sombra, cuerpo y un brillito más chico (escala 0.5)
	for pebble: Dictionary in _pebbles:
		var pebble_pos: Vector2 = pebble["position"]
		var pebble_angle: float = pebble["angle"]
		var pebble_shape: PackedVector2Array = pebble["shape"]
		var pebble_color: Color = pebble["color"]
		draw_set_transform(pebble_pos + Vector2(1.5, 2.0), pebble_angle, Vector2.ONE)
		draw_colored_polygon(pebble_shape, Color(0.3, 0.24, 0.14, 0.35))
		draw_set_transform(pebble_pos, pebble_angle, Vector2.ONE)
		draw_colored_polygon(pebble_shape, pebble_color)
		draw_set_transform(pebble_pos + Vector2(-1, -1), pebble_angle, Vector2(0.5, 0.5))
		draw_colored_polygon(pebble_shape, pebble_color.lightened(0.25))

	# Conchas: abanico con costillas
	for shell: Dictionary in _shells:
		var shell_pos: Vector2 = shell["position"]
		var shell_angle: float = shell["angle"]
		var shell_shape: PackedVector2Array = shell["shape"]
		var shell_color: Color = shell["color"]
		draw_set_transform(shell_pos, shell_angle, Vector2.ONE)
		draw_colored_polygon(shell_shape, shell_color)
		for k: int in range(1, shell_shape.size(), 2):
			draw_line(Vector2.ZERO, shell_shape[k], shell_color.darkened(0.25), 1.0)

	# Regresamos la transformación a la normal
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)