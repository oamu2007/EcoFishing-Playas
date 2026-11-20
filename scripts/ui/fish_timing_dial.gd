extends Control

const START_ANGLE: float = -PI * 0.5
const RADIUS: float = 44.0
const CREAM: Color = Color("#fff2ce")
const INK: Color = Color("#153b3b")
const MISS: Color = Color("#ac4545")
const SUCCESS: Color = Color("#3f9462")

var _progress: float
var _zone: Vector2


func update_dial(progress: float, zone: Vector2) -> void:
	_progress = progress
	_zone = zone
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = Vector2(size.x * 0.5, 57.0)
	draw_circle(center, 57.0, INK, true, -1.0, true)
	draw_arc(center, RADIUS, 0.0, TAU, 80, MISS, 9.0, true)
	var from: float = START_ANGLE + _zone.x * TAU
	var to: float = START_ANGLE + _zone.y * TAU
	draw_arc(center, RADIUS, from, to, 24, SUCCESS, 13.0, true)
	for angle: float in [from, to]:
		var direction: Vector2 = Vector2.from_angle(angle)
		draw_line(center + direction * 35.0, center + direction * 53.0, CREAM, 2.0, true)
	var marker: Vector2 = center + Vector2.from_angle(START_ANGLE + _progress * TAU) * RADIUS
	draw_circle(marker, 8.0, INK, true, -1.0, true)
	draw_circle(marker, 5.0, CREAM, true, -1.0, true)
