extends Control

const ART_SIZE: Vector2 = Vector2(300.0, 330.0)
const TITLE_SIZE: Vector2 = Vector2(960.0, 540.0)
const TITLE_SHORE: Array[Vector2] = [
	Vector2(825, -105), Vector2(774, -31), Vector2(730, 45),
	Vector2(736, 99), Vector2(769, 156), Vector2(773, 211),
	Vector2(739, 258), Vector2(662, 287), Vector2(624, 322),
	Vector2(620, 361), Vector2(565, 421), Vector2(579, 477),
	Vector2(566, 525), Vector2(492, 629),
]
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
const FOAM: Color = Color("d4ddbb")

@export_range(4.0, 30.0, 0.5) var motion_period: float = 12.0
@export var full_bleed: bool = false

var _motion_active: bool = false
var _phase: float = 0.0
var _baked_title_shore: PackedVector2Array


func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(_motion_active)
	if full_bleed:
		_bake_title_shore()


func set_motion_active(active: bool) -> void:
	if active == _motion_active:
		return
	_motion_active = active
	set_process(active)
	queue_redraw()


func _process(delta: float) -> void:
	_phase = fposmod(_phase + TAU * delta / motion_period, TAU)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if full_bleed:
		_draw_title()
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
	if _motion_active:
		_draw_surf()

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
	if _motion_active:
		_draw_pennant()
	_draw_fish()


func _bake_title_shore() -> void:
	var shoreline: Curve2D = Curve2D.new()
	shoreline.bake_interval = 4.0
	for index: int in TITLE_SHORE.size():
		var previous: Vector2 = TITLE_SHORE[maxi(0, index - 1)]
		var following: Vector2 = TITLE_SHORE[mini(TITLE_SHORE.size() - 1, index + 1)]
		var tangent: Vector2 = (following - previous) * 0.17
		shoreline.add_point(TITLE_SHORE[index], -tangent, tangent)
	_baked_title_shore = shoreline.get_baked_points()


func _draw_title() -> void:
	var cover: float = maxf(size.x / TITLE_SIZE.x, size.y / TITLE_SIZE.y)
	var origin: Vector2 = Vector2(size.x - TITLE_SIZE.x * cover, (size.y - TITLE_SIZE.y * cover) * 0.5)
	draw_polygon([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)],
		[Color("#102f3c"), Color("#15434c"), Color("#326e6e"), Color("#153e46")])
	draw_set_transform(origin, 0.0, Vector2.ONE * cover)
	_draw_title_band(-81.0, Color("#235960"))
	_draw_title_band(-47.0, Color("#347577"))
	_draw_title_band(-23.0, Color("#569385"))
	_draw_title_band(0.0, Color("#bbab7d"))
	_draw_title_band(12.0, Color("#efd39e"))
	_draw_title_band(76.0, Color("#e0be84"))
	_draw_title_band(135.0, Color("#c9a573"))
	_draw_title_surf()
	_draw_title_dunes()
	_draw_title_school(Vector2(542, 236), -0.49, 0.2)
	_draw_title_school(Vector2(432, 466), -0.85, 1.65)
	draw_set_transform(origin + Vector2(688, 258) * cover, -0.18, Vector2.ONE * cover * 1.32)
	_draw_shack()
	_draw_pennant()


func _draw_title_band(offset: float, tint: Color) -> void:
	var points: PackedVector2Array = [Vector2(1140, -105), Vector2(1140, 629)]
	for index: int in range(_baked_title_shore.size() - 1, -1, -1):
		points.append(_baked_title_shore[index] + Vector2(offset, 0.0))
	draw_colored_polygon(points, tint)


func _draw_title_surf() -> void:
	for band: int in 3:
		for start: int in range(14 + band * 13, _baked_title_shore.size() - 19, 33 + band * 6):
			var swell: float = sin(_phase * 2.0 + start * 0.11 + band * 0.9)
			var crest: PackedVector2Array = []
			for index: int in range(start, start + 18, 2):
				var point: Vector2 = _baked_title_shore[index]
				crest.append(point + Vector2(-3.0 - 23.0 * band + 4.5 * swell, 0.0))
			var opacity: float = (0.49 - 0.10 * band) * (0.78 + 0.22 * swell)
			draw_polyline(crest, Color(FOAM, opacity), 2.8 - 0.5 * band, true)
	_draw_glint(Vector2(655, 153), 0.3)
	_draw_glint(Vector2(481, 374), 2.6)
	_draw_glint(Vector2(594, 277), 1.8)
	_draw_glint(Vector2(705, 166), 5.0)
	draw_polyline([Vector2(912, 95), Vector2(879, 134), Vector2(866, 157), Vector2(853, 185)],
		Color("#af8d62"), 1.6, true)


func _draw_title_dunes() -> void:
	draw_polyline([Vector2(970, 349), Vector2(907, 377), Vector2(877, 390), Vector2(834, 420),
		Vector2(805, 455), Vector2(754, 486), Vector2(718, 521), Vector2(694, 554)],
		Color("#efd4a4"), 20.0, true)
	draw_polyline([Vector2(970, 390), Vector2(919, 433), Vector2(897, 477), Vector2(843, 521), Vector2(819, 558)],
		Color("#b89a6b"), 2.0, true)
	draw_polyline([Vector2(830, 46), Vector2(851, 62), Vector2(869, 95), Vector2(873, 115)],
		Color("#b89a6b"), 2.0, true)
	for reed: Vector2 in [Vector2(818, 72), Vector2(874, 102), Vector2(891, 154),
		Vector2(848, 249), Vector2(900, 280), Vector2(844, 328), Vector2(920, 318),
		Vector2(705, 343), Vector2(711, 394), Vector2(743, 445), Vector2(931, 455),
		Vector2(880, 477), Vector2(769, 512), Vector2(658, 511), Vector2(860, 532)]:
		_draw_reed(reed, 1.2)
	for rock: Vector2 in [Vector2(705, 310), Vector2(722, 307), Vector2(653, 390),
		Vector2(660, 399), Vector2(645, 398), Vector2(687, 453), Vector2(921, 199)]:
		draw_circle(rock + Vector2(2, 2), 5.0, Color("#ab916c"), true, -1.0, true)
		draw_circle(rock, 4.2, Color("#c7b28e"), true, -1.0, true)


func _draw_title_school(center: Vector2, angle: float, delay: float) -> void:
	var motion: Vector2 = Vector2(11.0 * sin(_phase + delay), 7.0 * cos(_phase + delay))
	for index: int in 5:
		var point: Vector2 = center + motion + Vector2(-14.0 * index, 13.0 * sin(index * 1.6))
		var heading: float = angle + 0.12 * sin(_phase * 3.0 + index)
		var silhouette: PackedVector2Array = []
		var tint: Color = Color("#548c86") if index % 2 == 0 else Color("#427775")
		for outline: Vector2 in [Vector2(11, 0), Vector2(2, 3), Vector2(-7, 1),
			Vector2(-12, 4), Vector2(-10, 0), Vector2(-12, -4), Vector2(-7, -1), Vector2(2, -3)]:
			silhouette.append(point + outline.rotated(heading))
		draw_colored_polygon(silhouette, tint)


func _draw_coast_band(offset: float, color: Color) -> void:
	var outline: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(ART_SIZE.x, 0)])
	for index: int in range(SHORE.size() - 1, -1, -1):
		outline.append(SHORE[index] + Vector2(0, offset))
	draw_colored_polygon(outline, color)


func _draw_contour(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, color, 1.1, true)


func _draw_surf() -> void:
	_draw_foam([Vector2(31, 300), Vector2(52, 291), Vector2(72, 276), Vector2(88, 261)], 0.0)
	_draw_foam([Vector2(110, 236), Vector2(126, 222), Vector2(142, 211), Vector2(163, 202)], 0.9)
	_draw_foam([Vector2(212, 182), Vector2(229, 172), Vector2(249, 151), Vector2(267, 130)], 1.8)
	_draw_glint(Vector2(115, 287), 0.5)
	_draw_glint(Vector2(246, 283), 2.4)
	_draw_glint(Vector2(272, 212), 4.4)


func _draw_foam(points: PackedVector2Array, delay: float) -> void:
	var swell: float = sin(2.0 * _phase - delay)
	var crest: PackedVector2Array = []
	for point: Vector2 in points:
		crest.append(point + Vector2(1.5, 3.4) * swell)
	_draw_contour(crest, Color(FOAM, 0.40 + 0.28 * swell))


func _draw_glint(center: Vector2, delay: float) -> void:
	var swell: float = sin(2.0 * _phase + delay)
	var length: float = 3.5 + 2.0 * swell
	var offset: Vector2 = Vector2(1.0, -0.4) * swell
	draw_line(center + offset - Vector2(length, 0), center + offset + Vector2(length, 0), Color(FOAM, 0.36 + 0.26 * swell), 1.0, true)


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


func _draw_pennant() -> void:
	var mast: Vector2 = Vector2(115, 71)
	var flutter: float = sin(_phase * 5.0)
	draw_line(mast + Vector2(0, 16), mast, Color("71503a"), 1.4, true)
	draw_colored_polygon([
		mast, mast + Vector2(7, -1 + flutter), mast + Vector2(16, 3 + 2 * flutter),
		mast + Vector2(7, 6 + flutter), mast + Vector2(0, 6),
	], Color("b77458"))


func _draw_fish() -> void:
	var offset: Vector2 = Vector2.ZERO
	var tail: float = 0.0
	if _motion_active:
		offset = Vector2(17.0 * sin(_phase), 8.0 * sin(_phase + 0.64))
		tail = 2.0 * sin(_phase * 6.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(185, 262) + offset, Vector2(194, 254) + offset, Vector2(207, 250) + offset,
		Vector2(216, 253) + offset, Vector2(208, 262) + offset, Vector2(195, 267) + offset,
		Vector2(185, 266) + offset, Vector2(176, 274 + tail) + offset, Vector2(176, 261 + tail) + offset,
	]), Color("86a799"))
	draw_circle(Vector2(210, 254) + offset, 1.35, OCEAN, true, -1.0, true)
