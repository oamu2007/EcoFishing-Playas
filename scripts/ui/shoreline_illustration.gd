extends Control

const ART_SIZE: Vector2 = Vector2(300.0, 330.0)
const SHORE: Array[Vector2] = [
	Vector2(0, 286), Vector2(21, 280), Vector2(41, 271), Vector2(64, 255),
	Vector2(84, 234), Vector2(106, 210), Vector2(125, 195), Vector2(155, 181),
	Vector2(184, 171), Vector2(205, 158), Vector2(223, 140), Vector2(239, 118),
	Vector2(257, 96), Vector2(275, 84), Vector2(300, 75),
]
const OCEAN: Color = Color("184b50")
const COASTAL_WATER: Color = Color("265e5d")
const SHALLOWS: Color = Color("457967")
const WET_SAND: Color = Color("bb9f73")
const BEACH: Color = Color("e1c99e")
const UPLAND: Color = Color("d2b482")
const DUNE: Color = Color("c6a879")
const WATER_MARK: Color = Color("61958a")
const DUNE_MARK: Color = Color("a58f64")


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / ART_SIZE)
	draw_rect(Rect2(Vector2.ZERO, ART_SIZE), OCEAN)
	_draw_coast_band(41.0, COASTAL_WATER)
	_draw_coast_band(20.0, SHALLOWS)
	_draw_coast_band(0.0, WET_SAND)
	_draw_coast_band(-9.0, BEACH)
	_draw_coast_band(-48.0, UPLAND)
	_draw_coast_band(-71.0, DUNE)

	_draw_contour([Vector2(25, 299), Vector2(48, 289), Vector2(72, 271),
		Vector2(94, 249), Vector2(112, 228), Vector2(136, 210)], Color("85a48b"))
	_draw_contour([Vector2(204, 182), Vector2(228, 164), Vector2(246, 143),
		Vector2(261, 124), Vector2(282, 107), Vector2(299, 100)], Color("85a48b"))
	_draw_contour([Vector2(145, 227), Vector2(171, 216), Vector2(190, 210)], WATER_MARK)
	_draw_contour([Vector2(220, 205), Vector2(236, 195), Vector2(250, 182)], WATER_MARK)
	_draw_contour([Vector2(59, 312), Vector2(73, 304), Vector2(89, 291)], WATER_MARK)
	_draw_contour([Vector2(259, 258), Vector2(273, 253), Vector2(287, 245)], WATER_MARK)
	_draw_contour([Vector2(171, 303), Vector2(188, 300), Vector2(207, 291)], WATER_MARK)
	_draw_contour([Vector2(281, 175), Vector2(292, 167)], WATER_MARK)

	_draw_contour([Vector2(0, 188), Vector2(20, 182), Vector2(37, 171),
		Vector2(53, 159), Vector2(64, 148)], DUNE_MARK)
	_draw_contour([Vector2(144, 98), Vector2(165, 88), Vector2(188, 81),
		Vector2(204, 70), Vector2(219, 56)], DUNE_MARK)
	_draw_contour([Vector2(5, 217), Vector2(27, 210), Vector2(49, 196)], Color("b49a6e"))
	_draw_reed(Vector2(32, 118), 1.0)
	_draw_reed(Vector2(146, 55), 0.9)
	_draw_reed(Vector2(57, 66), 0.75)
	_draw_reed(Vector2(15, 228), 0.8)
	_draw_reed(Vector2(190, 103), 0.7)
	_draw_shack()
	_draw_fish()


func _draw_coast_band(offset: float, color: Color) -> void:
	var outline: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(ART_SIZE.x, 0)])
	for index: int in range(SHORE.size() - 1, -1, -1):
		outline.append(SHORE[index] + Vector2(0, offset))
	draw_colored_polygon(outline, color)


func _draw_contour(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, color, 1.1, true)


func _draw_reed(base: Vector2, scale_factor: float) -> void:
	var color: Color = Color("807a4c")
	draw_line(base, base + Vector2(-6, -7) * scale_factor, color, 1.5, true)
	draw_line(base, base + Vector2(-1, -10) * scale_factor, color, 1.5, true)
	draw_line(base, base + Vector2(5, -8) * scale_factor, color, 1.5, true)


func _draw_shack() -> void:
	draw_polyline(PackedVector2Array([
		Vector2(104, 145), Vector2(107, 158), Vector2(105, 175), Vector2(94, 193),
	]), Color("ebd4aa"), 13.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(65, 98), Vector2(133, 98), Vector2(145, 114), Vector2(145, 147),
		Vector2(117, 152), Vector2(67, 150),
	]), Color("896746"))
	draw_rect(Rect2(68, 102, 68, 37), Color("6a4536"))
	draw_rect(Rect2(68, 132, 68, 13), Color("a37854"))
	draw_rect(Rect2(91, 136, 19, 15), Color("7c513b"))
	draw_line(Vector2(91, 144), Vector2(110, 144), Color("be9567"), 2.0)
	draw_line(Vector2(91, 149), Vector2(110, 149), Color("be9567"), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(63, 104), Vector2(75, 86), Vector2(127, 86), Vector2(140, 104),
	]), Color("a86c4b"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(63, 104), Vector2(140, 104), Vector2(134, 124), Vector2(68, 124),
	]), Color("82523f"))
	draw_line(Vector2(63, 104), Vector2(140, 104), Color("d1a473"), 2.0, true)
	for plank_x: int in range(80, 133, 10):
		draw_line(Vector2(plank_x, 106), Vector2(plank_x, 123), Color("674335"), 1.0)


func _draw_fish() -> void:
	var body: Color = Color("86a799")
	draw_colored_polygon(PackedVector2Array([
		Vector2(185, 262), Vector2(194, 254), Vector2(207, 250), Vector2(216, 253),
		Vector2(208, 262), Vector2(195, 267), Vector2(185, 266), Vector2(176, 274),
		Vector2(176, 261),
	]), body)
	draw_circle(Vector2(210, 254), 1.35, OCEAN, true, -1.0, true)
