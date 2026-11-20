extends Node2D

const INK: Color = Color("#293b3a")
const SAND: Color = Color("#edcd96")
const DEEP: Color = Color("#365f64")
const WATER: Color = Color("#6f9c8d")
const SEAFOAM: Color = Color("#c4e0bf")
const ORANGE: Color = Color("#d7864d")
const GEAR: Color = Color("#27666a")
const SILT: Color = Color("#787256")
const ROCK: Color = Color("#9a886f")

const ARRIVED: float = 0.26
const WORK_DONE: float = 0.77
const DEBRIS: Array[Vector2] = [
	Vector2(-23, -1), Vector2(-10, 12), Vector2(-4, -10), Vector2(12, 6), Vector2(24, -8),
]
const POOL_RIM: PackedVector2Array = [
	Vector2(-30, -3), Vector2(-21, -14), Vector2(-4, -17), Vector2(18, -14),
	Vector2(31, -2), Vector2(27, 10), Vector2(10, 16), Vector2(-11, 14), Vector2(-27, 7),
]

@export_enum("Shore debris", "Offshore net", "Tide pool") var work_kind: int = 0
@export_range(0.5, 10.0, 0.1) var duration: float = 3.2
@export var watch_cue: String

var has_started: bool:
	get:
		return _started
var is_complete: bool:
	get:
		return progress >= 1.0
var progress: float:
	get:
		return clampf(_elapsed / duration, 0.0, 1.0)

var _started: bool
var _elapsed: float


func start() -> void:
	if not _started:
		_started = true
		queue_redraw()


func advance(delta: float) -> void:
	if _started and not is_complete:
		_elapsed = minf(duration, _elapsed + maxf(0.0, delta))
		queue_redraw()


func _draw() -> void:
	var work: float = smoothstep(ARRIVED, WORK_DONE, progress)
	match work_kind:
		0:
			_draw_shore(work)
		1:
			_draw_net(work)
		2:
			_draw_pool(work)


func _crew_offset() -> Vector2:
	var approach: float = 1.0 - smoothstep(0.0, ARRIVED, progress)
	var departure: float = smoothstep(WORK_DONE, 1.0, progress)
	return Vector2(-43.0 * (approach + departure), 13.0 * (approach + departure))


func _draw_shore(work: float) -> void:
	_ellipse(Vector2(0, 3), Vector2(30, 14), Color("#b79862"))
	if work < 1.0:
		for index: int in DEBRIS.size():
			var gathered: float = smoothstep(index * 0.12, 0.52 + index * 0.12, work)
			if gathered < 0.98:
				_debris(DEBRIS[index].lerp(Vector2(-25, 15), gathered), index)
	else:
		_ellipse(Vector2(0, 3), Vector2(29, 13), SAND)
		_draw_grass(Vector2(-21, -1))
		_draw_grass(Vector2(19, 7))
		_line(Vector2(-8, 6), Vector2(5, 4), Color("#d3ac77"), 1.5)
	if _started and not is_complete:
		var offset: Vector2 = _crew_offset()
		var stride: float = sin(progress * TAU * 5.0)
		var worker: Vector2 = Vector2(-22 + 33 * work, -16) + offset
		_draw_worker(worker, stride)
		_draw_worker(Vector2(-24, 14) + offset, -stride)
		var rake_end: Vector2 = worker + Vector2(6, 15 + 3 * stride)
		_line(worker + Vector2(-3, 3), rake_end, SAND, 2.8)
		_line(rake_end + Vector2(-4, 0), rake_end + Vector2(4, 0), INK, 2.0)
		_draw_bag(Vector2(-17, 18) + offset, work)


func _draw_net(work: float) -> void:
	if work < 1.0:
		_draw_mesh(Vector2(0, -24 * work), Vector2(1.0 - 0.53 * work, 1.0 - 0.55 * work))
	else:
		_ellipse(Vector2.ZERO, Vector2(23, 9), Color("#72afad77"), false)
		_ellipse(Vector2(0, 1), Vector2(14, 5), Color("#afd3c48c"), false)
		_draw_float(Vector2(0, -3))
	if _started and not is_complete:
		var approach: float = 1.0 - smoothstep(0.0, ARRIVED, progress)
		var departure: float = smoothstep(WORK_DONE, 1.0, progress)
		var skiff: Vector2 = Vector2(44 * (approach + departure), -28.0 + sin(progress * TAU * 3.0))
		_ellipse(skiff + Vector2(8, 3), Vector2(27, 11), Color("#afd3c486"), false)
		_polygon(skiff, [Vector2(-23, 0), Vector2(-12, -10), Vector2(14, -10), Vector2(23, -6),
			Vector2(23, 6), Vector2(14, 10), Vector2(-12, 10)], SAND, INK, 2.2)
		draw_rect(Rect2(skiff + Vector2(-10, -6), Vector2(26, 12)), DEEP)
		_draw_worker(skiff + Vector2(1, -2), 0.0)
		_draw_crate(skiff + Vector2(13, 0), work >= 1.0)
		if progress >= ARRIVED and progress < WORK_DONE:
			_line(skiff + Vector2(-7, 4), Vector2(-7, -24 * work), SAND, 2.0)
			_draw_wave(Vector2(-9, 3 + 2 * sin(progress * TAU * 6.0)))


func _draw_pool(work: float) -> void:
	_polygon(Vector2.ZERO, POOL_RIM, SILT, INK, 2.0)
	_ellipse(Vector2(0, -1), Vector2(24, 11), SILT.lerp(WATER, work))
	for stone: Vector2 in [Vector2(-24, -7), Vector2(-17, 10), Vector2(13, -13), Vector2(26, 5)]:
		_ellipse(stone + Vector2(0, 1), Vector2(5, 3), INK)
		_ellipse(stone, Vector2(4, 2.4), ROCK)
	if work < 1.0:
		draw_polyline([Vector2(-13, 2), Vector2(-5, -5), Vector2(2, 3), Vector2(10, -3)],
			Color(SAND, maxf(0.0, 1.0 - work)), 2.0, true)
		if work < 0.75:
			_debris(Vector2(13, 4).lerp(Vector2(2, -15), work), 3)
	else:
		_draw_wave(Vector2(-13, -3))
		_draw_wave(Vector2(4, 6))
		_draw_grass(Vector2(-17, 7))
		draw_circle(Vector2(10, -4), 2.8, ORANGE, true, -1.0, true)
	if _started and not is_complete:
		var offset: Vector2 = _crew_offset()
		var stride: float = sin(progress * TAU * 5.0)
		var worker: Vector2 = Vector2(-17 + 18 * work, -23) + offset
		_draw_worker(worker, stride)
		_draw_worker(Vector2(-20, 23) + offset, -stride)
		var scoop: Vector2 = worker + Vector2(4, 17.0 - 4.0 * stride)
		_line(worker + Vector2(4, 1), scoop, SAND, 2.4)
		_ellipse(scoop, Vector2(4, 2), DEEP)
		_draw_crate(Vector2(-14, 24) + offset, work > 0.5)


func _draw_mesh(center: Vector2, mesh_scale: Vector2) -> void:
	draw_set_transform(center, -0.14, mesh_scale)
	draw_rect(Rect2(-22, -8, 44, 16), Color("#273e3dbf"))
	for x: int in range(-20, 21, 8):
		_line(Vector2(x - 3, -8), Vector2(x + 3, 8), Color("#8d9274"), 1.2)
	_line(Vector2(-22, 0), Vector2(22, 0), Color("#8d9274"), 1.2)
	for x: int in [-22, 0, 22]:
		_draw_float(Vector2(x, -8))
	draw_set_transform(Vector2.ZERO)


func _debris(point: Vector2, index: int) -> void:
	var color: Color = [Color("#5c9878"), ORANGE, SAND][index % 3]
	_polygon(point, [Vector2(-4, -3), Vector2(2, -4), Vector2(5, 0), Vector2(3, 4), Vector2(-3, 2)],
		color, INK, 1.4)


func _draw_worker(center: Vector2, stride: float) -> void:
	_ellipse(center + Vector2(0, 5), Vector2(7, 5), Color("#263c385e"))
	_line(center + Vector2(-2, 1), center + Vector2(-3, 8 + stride), INK, 2.6)
	_line(center + Vector2(2, 1), center + Vector2(3, 8 - stride), INK, 2.6)
	_polygon(center, [Vector2(-5, -4), Vector2(5, -4), Vector2(6, 4), Vector2(-6, 4)], GEAR, INK, 1.3)
	_line(center + Vector2(-4, 1), center + Vector2(4, 1), SEAFOAM, 1.3)
	draw_circle(center + Vector2(0, -5), 4.5, INK, true, -1.0, true)
	draw_circle(center + Vector2(0, -6), 3.6, ORANGE, true, -1.0, true)


func _draw_grass(point: Vector2) -> void:
	for blade: Vector2 in [Vector2(-4, -5), Vector2(-1, -8), Vector2(3, -6)]:
		_line(point, point + blade, GEAR, 1.8)


func _draw_wave(point: Vector2) -> void:
	draw_polyline(PackedVector2Array([point + Vector2(-5, 1), point, point + Vector2(4, 1)]), SEAFOAM, 1.5, true)


func _draw_float(point: Vector2) -> void:
	draw_circle(point, 4.1, INK, true, -1.0, true)
	draw_circle(point, 2.9, ORANGE, true, -1.0, true)
	_line(point + Vector2(-1, -1), point + Vector2(1, -1), SAND, 1.2)


func _draw_bag(point: Vector2, fill: float) -> void:
	_ellipse(point, Vector2(4 + 3 * fill, 5 + 2 * fill), INK)
	_ellipse(point - Vector2(0, 1), Vector2(3 + 3 * fill, 4 + 2 * fill), DEEP)
	_line(point + Vector2(-2, -5), point + Vector2(2, -5), SAND, 1.6)


func _draw_crate(point: Vector2, loaded: bool) -> void:
	draw_rect(Rect2(point - Vector2(5, 4), Vector2(10, 8)), INK)
	draw_rect(Rect2(point - Vector2(4, 3), Vector2(8, 6)), ORANGE if loaded else ROCK)
	if loaded:
		_line(point + Vector2(-3, 2), point + Vector2(3, -2), DEEP, 1.5)


func _ellipse(center: Vector2, radii: Vector2, color: Color, filled: bool = true) -> void:
	var points: PackedVector2Array = []
	for index: int in 29:
		points.append(center + Vector2.from_angle(TAU * index / 28.0) * radii)
	if filled:
		points.resize(28)
		draw_colored_polygon(points, color)
	else:
		draw_polyline(points, color, 1.4, true)


func _polygon(center: Vector2, shape: PackedVector2Array, color: Color, stroke: Color, width: float) -> void:
	var points: PackedVector2Array = []
	for point: Vector2 in shape:
		points.append(center + point)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, stroke, width, true)


func _line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, true)
